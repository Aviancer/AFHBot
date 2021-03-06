module AFHBot

  require 'discordrb'

  class DiscordClient

    def initialize(log, config)
      @log = log
      @log.info("Initializing DiscordClient")

      token = config.get['token']
      client_id = config.get['client_id']
      @discord_bot = Discordrb::Commands::CommandBot.new token: token, prefix: '!'
    end

    def register(moduleconfig, controller)
      @log.info("Registering module #{controller}")
      controller.commands(@log, moduleconfig).each do |command|
        @log.info("- Registering command #{command.name}")
        @discord_bot.command(command.name, command.attributes, &command.block)
      end
    end

    def run
      @log.info("Connecting to Discord service")
      @discord_bot.run
    end

    def join
      @discord_bot.join
    end

  end

end
