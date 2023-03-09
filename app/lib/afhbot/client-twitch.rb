module AFHBot

  class TwitchClient

    def initialize(log, queues, twitch)
      @log = log
      @tx_queue = queues[:tx_queue]
      @rx_queue = queues[:rx_queue]
      @twitch = twitch
      
      @connect_delay = 1

      @event_handlers = {}
    end

    def client_thread
      loop do
        sleep @connect_delay if @connect_delay > 1
    
        result = @twitch.server_connect
        unless result == true
          @connect_delay = @connect_delay * 2
          @log.error("Failed to connect to %s:%s, error: %p. Waiting %s second(s) to retry." % [@twitch.config["server_addr"], @twitch.config["server_port"], result, @connect_delay])
          next
        end
    
        result = @twitch.login
        unless result == true
          @connect_delay = @connect_delay * 2
          @log.error("Failed to @login as %s, waiting %s second(s) to retry" % [@twitch.config["nickname"], @connect_delay])
          next
        else
          @connect_delay = 1
        end
    
        @log.info("Joining channel(s): #{@twitch.config["channels"].join(", ")}")
        @twitch.join(@twitch.config["channels"])
   
        @twitch.server_gets_each do |message|
          parsed = @twitch.parse(message)
          next if parsed.nil? # Discard malformed messages, logged by parser
          @log.server(parsed)
      
          case parsed[:command]
          when "PING"
            @twitch.pong(parsed[:params])
            @log.info("Sent pong %p" % parsed[:params])
          when "#{AFHBot::TwitchProto::CMD_MEMBERSHIP}"
            channel, members = @twitch.parseparams_members(parsed[:params])
            @log.info("Members on channel %s: %s" % [channel, members])
          end

          #@twitch.queue << message
          handle(parsed)
        end
      end
    end

    def handle(event)
        @event_handlers.fetch(event[:command]).call(@twitch, event)
    rescue KeyError
        @log.debug("Unhandled event: #{event}")
    end
    
    def initialize_commands(moduleconfig, controller)
        @log.info("Initializing module #{controller}")
        controller.commands(@log, moduleconfig).each do |command|
            @log.info("- Adding handler for message type #{command.name}")

            @event_handlers[command.name] = command.block
        end
    end

  end
end
