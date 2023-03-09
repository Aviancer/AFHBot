module AFHBot

  class Log
    
    attr_accessor :debug

    def initialize(debug: nil)
      @debug = debug
    end

    def time
      Time.now.strftime("%Y-%m-%d %H:%M:%S")
    end

    def debug(message, forced: nil)
      if @debug or forced
        puts "%s DEBUG: %p" % [time(), message]
        STDOUT.flush
      end
    end
    
    def info(message)
      puts "%s INFO (%s): %p" % [time(), Thread.current.name, message]
      STDOUT.flush
    end

    def warning(message)
      puts "%s WARNING (%s): %p" % [time(), Thread.current.name, message]
      STDOUT.flush
    end

    def error(message)
      puts "%s ERROR (%s): %p" % [time(), Thread.current.name, message]
      STDOUT.flush
    end
    
    def critical(message)
      puts "%s CRITICAL (%s): %p" % [time(), Thread.current.name, message]
      STDOUT.flush
    end

    def server(message)
      puts "%s Server (%s): %p" % [time(), Thread.current.name, message]
      STDOUT.flush
    end
  end

end
