module AFHBot

  module TwitchResponses
    
    def self.commands(log, moduleconfig)
      [
       AFHBot::Command.new(
         'PRIVMSG',
         { :description => 'Private messages' }, 
         privmsg(log, moduleconfig))
      ]
    end

    def self.privmsg(log, moduleconfig)
      # twitch is an instantiated TwitchProto object
      ->(twitch, event, *args) do # stabby lambda
        # :aviancer!aviancer@aviancer.tmi.twitch.tv
        msg_from = event[:prefix].delete_prefix(":").split('!').first
        msg_to, msg_text = twitch.parseparams_privmsg(event[:params])

        if msg_text.chars.first == moduleconfig["command-prefix"]
          case msg_text
          when "!test"
            twitch.msg(msg_to, "Self-test: OK") # TODO: What if message isn't to a channel?
          end
        end

      end
    end

    def self._logevent(log, method, event, level: :debug)
      # Max length willing to log of message is 512 characters.
      message = event.options.inspect() # Will contain each event 'option' parameter
      if message.length > 512
        message = message[0,512] + "..."
      end
      # send dynamically calls the method in log defined by 'level', eg. log.debug
      log.send(level, "AFHBot::Group::#{method} event: srv(#{event.channel.server.name}) src(#{_event2author(event)}) msg(#{message})")
    end

    def self._catcherror(log, method, event, msg, no_chat: false)
      log.error([msg, "-- Trace follows:"].join(" "))
       _logevent(log, method, event, level: :error)
       event.respond(content: "Error: #{msg}") unless no_chat
    end

  end
end
