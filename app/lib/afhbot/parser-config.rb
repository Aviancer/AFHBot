module AFHBot

  require 'yaml'

  class Config

    def initialize(log, file=nil)
      @log = log
      @settings = Hash.new

      unless file.nil? 
        if File.exist?(file) 
          self.load(file)
        else
          raise IOError.new("Unable to load configuration, file(#{file}) doesn't exist.")
        end
      end
    end

    def load(file)
      @log.info("Loading configuration file (#{file})")
      @settings = YAML.safe_load(File.read(file))
    end

    def get
      @settings
    end

  end

end

