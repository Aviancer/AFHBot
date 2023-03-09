module AFHBot

# Todo: Rate limiting

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
      @socket.puts "PRIVMSG #{target} :#{message}"
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

