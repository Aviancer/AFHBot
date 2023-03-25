require 'time'

module AFHBot

  class TwitchProto

    # Message constants
    CMD_MEMBERSHIP = 353

    attr_accessor :config
  
    def initialize(log, socket, config)
      @log = log
      @socket = socket
      @config = config

      # Null characters are not valid 
      @msg_pattern = %r{
        ^(?:(?<prefix>:[[:graph:]]+)\s?)?          # Optional prefix <space>
        (?<command>[[:alnum:]]+)(\s)?              # Command  
        (?::)?(?<params>.*?)                       # Optional (:)Parameters
        [\r\n]*$                                   # End
      }x
      @msg_buffer = ""

      # Message rate limiting
      @ratelimit_counters = { :PROTO_PRIVMSG => 0 }      # How many messges have we sent recently
      @ratelimit_timers = { :PROTO_PRIVMSG => Time.now } # Time since last limit period started
    end

    def add_rate_limiter(context)
      if not @ratelimit_counters.key? context
        @ratelimit_counters[context] = 0
        @ratelimit_timers[context] = Time.now
      end
    end

    # Simple instanced rate limiter
    def rate_limited?(context, max, period)
      if Time.now - @ratelimit_timers[context] > 30
        @ratelimit_timers[context] = Time.now
        @ratelimit_counters[context] = 0
      end

      @ratelimit_counters[context] += 1

      if @ratelimit_counters[context] <= max
        return false # Rate OK
      elsif @ratelimit_counters[context] == (max+1)
        @log.warning("Rate limiter for '#{context}' exceeded limit of #{max} in #{period} seconds.")
      end
      return true
    end    

    # <message>  ::= [':' <prefix> <SPACE> ] <command> <params> <crlf>
    def parse(message)
      parsed = @msg_pattern.match(message)
      if parsed.nil? then
        @log.error("Malformed message received: %p" % message)
      end
      parsed
    end

    # Verify channel is in configuration
    def allowed_channel?(channel)
      @config['channels'].include?(channel)
    end

    def parseparams_members(params)
      # <parsed_msg> ronni = #dallas :ronni fred wilma
      params_parts = params.
                     partition(" :")
      channel = params_parts.first.split(" = ").last
      members = params_parts.last.split(" ")
      return channel, members
    end

    def parseparams_privmsg(params)
      # <parsed_msg> #aviancer :Test7 more words
      params_parts = params.
                     partition(" :")
      channel = params_parts.first
      message = params_parts.last
      return channel, message
    end
  
    def login
      @socket.puts "PASS #{@config["password"]}"
      @socket.puts "NICK #{@config["nickname"]}"

      # Login success: :tmi.twitch.tv 001 <user> :Welcome, GLHF!
      parsed = parse(@socket.gets)
      @log.server(parsed)
      if parsed.nil? or (not parsed.names.include? 'params') then
        return false
      elsif parsed[:command] == "001" && parsed[:params].split(":")[1] == "Welcome, GLHF!"
        return true
      else
        return false
      end
    end
    
    def pong(target)
      @socket.puts "PONG :#{target}"
    end

    def join(channels)
      # Check channels have "#"
      # Check if channels empty, give error
      @socket.puts "JOIN #{(channels).join(" ")}"
    end
  
    def part(channels)
      @socket.puts "PART #{channels.join(" ")}"
    end
  
    def msg(target, message)
      # Simple rate limit to 20 messages per 30 seconds (Twitch stated limit)
      if not self.rate_limited?(:PROTO_PRIVMSG, 20, 30)
        @socket.puts "PRIVMSG #{target} :#{message}"
      end
    end
  
    def mode(target, flags)
      @socket.puts "MODE #{target} #{flags}"
    end
  
    def quit 
      @socket.puts "QUIT"
      @socket.close
    end

    ### Passthrough functions
    
    def server_connect
      @log.info("Connecting to #{@config["server_addr"]}:#{@config["server_port"]}")
      return @socket.connect
    end

    def server_gets!(length=$/)
      @msg_buffer = @socket.gets(length)
      @msg_buffer
    end

    def server_read(length)
      @socket.read(length)
    end

    def server_gets_each
      while @socket.alive?
        if @socket.readable?
          server_gets!
          yield @msg_buffer
        else
          sleep(0.1)
        end
      end
    end
  
  end

end

