module AFHBot

  module TwitchResponses

    class Responses

      @@allowed_methods = ['hello','ping']

      def self.allowed_method?(method_name)
        return true if @@allowed_methods.include? method_name
        false 
      end
 
      def self.hello(twitch, msg)
        twitch.msg(msg['to'], "Hello #{msg['from']}!")
      end

      def self.ping(twitch, msg)
        twitch.msg(msg['to'], "Pong!")
      end

    end
    
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
        msg = {
          'from' => event[:prefix].delete_prefix(":").split('!').first
        }
        msg['to'], msg['text'] = twitch.parseparams_privmsg(event[:params])

        # TODO: What if message isn't to a channel?
        if msg['text'].chars.first == moduleconfig["command-prefix"]
          msg['command'] = 
            msg['text'].delete_prefix(moduleconfig["command-prefix"]) # Strip command prefix -> method name
            .split(" ")
            .first
            .downcase
          if AFHBot::TwitchResponses::Responses.allowed_method?(msg['command'])
            AFHBot::TwitchResponses::Responses.send(msg['command'], twitch, msg)
          else
            log.debug("Unrecognized Twitch chat command: #{msg['command']}")
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
