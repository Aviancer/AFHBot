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

      # Rate limiting
      @msg_rate = 0                                # How many messges have we sent recently
      @msg_rate_timer = Time.now                   # Time since last limit period started
    end

    # Simple instance rate limit to 5 messages per 30 seconds (Twitch stated limit)
    def rate_limited?
      if Time.now - @msg_rate_timer > 30
        @msg_rate_timer = Time.now
        @msg_rate = 0
      end

      @msg_rate += 1

      if @msg_rate <= 5
        return false # Rate OK
      elsif @msg_rate == 6
        @log.warning("Hit Twitch rate limit of 5 messages in 30 seconds. Discarding responses.")
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
      @socket.puts "PASS oauth:#{@config["password"]}"
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
      if not self.rate_limited?
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
      result = @socket.connect
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

