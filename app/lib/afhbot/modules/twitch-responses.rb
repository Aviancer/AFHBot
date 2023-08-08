module AFHBot

  require 'open-uri'

  module TwitchResponses

    class Responses

      @@allowed_methods = ['help', 'discord', 'lurk' 'midi']

      def self.allowed_method?(method_name)
        @@allowed_methods.include? method_name
      end

      def self.help(log, twitch, msg)
        command_list = @@allowed_methods.map { |k|
                            "#{twitch.config['command-prefix']}#{k}" }
                            .join(' ')
        twitch.msg(msg['to'], "List of commands: #{command_list}")
      end

      def self.discord(log, twitch, msg)
        twitch.msg(msg['to'], "Invite to Aviancer's Discord: https://discord.gg/WQHju3U")
      end

      def self.lurk(log, twitch, msg)
        twitch.msg(msg['to'], "#{msg['from']} is now lurking. Thanks for helping the stream grow! Have a comf time, make sure to say hi if you wanted a reply.")
      end

      def self.quote(log, twitch, msg)
        # By, Quote, (Time)

        # ie. allow for others to be quoted as well.
        # Return #number for quote

        # How do we keep bot from recording things off stream though?
      end

      def self.learn(log, twitch, msg)
        # Learn definitions: name, definition

        # Use another command to read them back.
      end

      def self.seen(log, twitch, msg)
        # When was 'nick' last seen on channel

        # Consider actual presence or just messaging?
      end

      # vgmusic.com random midi integration
      def self.midi(log, twitch, msg)
        twitch.add_rate_limiter(:RESPONSES_MIDI)
        if twitch.rate_limited?(:RESPONSES_MIDI, 5, 10)
          twitch.msg(msg['to'], "Midi Radio is on cooldown, wait a bit and try again.")
          return
        end

        begin
          doc = URI.open("https://www.vgmusic.com/cgi/random.cgi?") { |io| io.read() }
        rescue => error
          twitch.msg(msg['to'], "Midi Radio: Ran into an error, failed to get a random midi.")
          log.error("AFHBot::TwitchResponses::#{__method__}: Failed to query vgmusic.com: #{error}")
          return
        end

        patterns = {
          :url => /(?:(?<=You are listening to:<br>\n)<a href=")(.{1,100})">/m,
          :length => /Song Play Length:(:? (.{1,20}?))</m,
          :system => /Game System:(:? (.{1,30}?))<br>/m,
          :game => /Game Name:(:? (.{1,50}?))<br>/m,
          :title => /Song Title:(:? (.{1,50}?))<br>/m
        }
        
        midi = patterns.map do |key, regexp|
          result = doc.match(regexp)
          # If match found, return match. Otherwise default.
          [key, result ? result[1].strip : "Unknown #{key}"]
        end.to_h

        reply = "Midi Radio: #{midi[:url]} -> " \
                 "'#{midi[:title]}' from '#{midi[:game]}' on " \
                 "#{midi[:system]}. Length: #{midi[:length]}."
        log.info("AFHBot::TwitchResponses::#{__method__} suggesting #{reply}")
        twitch.msg(msg['to'], reply)
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

        # Filter out messages not sent to channels in configuration
        return if not twitch.allowed_channel?(msg['to'])

        if msg['text'].chars.first == moduleconfig["command-prefix"]
          msg['command'] = 
            msg['text'].delete_prefix(moduleconfig["command-prefix"]) # Strip command prefix -> method name
            .split(" ")
            .first
            .downcase
          if Responses.allowed_method?(msg['command'])
            _logevent(log, __method__, msg, level: :info)
            Responses.send(msg['command'], log, twitch, msg)
          else
            log.debug("Nick '#{msg['from']}' sent unrecognized Twitch chat command: #{msg['command']}")
            _logevent(log, __method__, msg, level: :debug)
          end
        end

      end
    end

    def self._logevent(log, method, event, level: :debug)
      # Max length willing to log of message is 512 characters.
      message = event.inspect() # Will contain each event 'option' parameter
      if message.length > 512
        message = message[0,512] + "..."
      end
      # send dynamically calls the method in log defined by 'level', eg. log.debug
      log.send(level, "AFHBot::TwitchResponses::#{method} event: chn(#{event['to']}) src(#{event['from']}) msg(#{message})")
    end

    def self._catcherror(log, method, event, msg, no_chat: false)
      log.error([msg, "-- Trace follows:"].join(" "))
       _logevent(log, method, event, level: :error)
       event.respond(content: "Error: #{msg}") unless no_chat
    end

  end
end
