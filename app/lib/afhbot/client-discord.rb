module AFHBot

  require 'discordrb'

  class DiscordClient

    def initialize(log, config)
      @log = log
      @log.info("Initializing DiscordClient")

      token = config.get['token']
      client_id = config.get['client_id']
      @discord_bot = Discordrb::Bot.new(token: token, intents: [:server_messages])

    end

    # Register application commands, this should only be done on first run or if the commands are updated.
    def register_commands(moduleconfig, controller)
      @log.info("Registering module #{controller}")
      controller.commands(@log, moduleconfig).each do |command|
        @log.info("- Registering command #{command.name}")

        @discord_bot.register_application_command(command.name, command.attributes[:description], server_id: moduleconfig.fetch('server_id')) do |app_cmd|
          command.attributes.fetch(:args, {}).each_pair do |name, desc|
            app_cmd.string(name, desc)
          end
        end
      end
    end

    # Unregister all application commands (NOTE: Does not currently return anything?)
    def unregister_commands(moduleconfig, controller)
      @log.error("This command currently does nothing! Unable to fetch application commands. Library bug?")
      server_id = moduleconfig.fetch('server_id')
      @log.info("Unregistering all application commands on server id: #{server_id}")
      @discord_bot.get_application_commands(server_id: server_id) do |app_cmd|
        @discord_bot.get_application_command(app_cmd.id, server_id) 
        @log.info("- Unregistering command #{app_cmd.name}##{app_cmd.id}@#{server_id}")
        @discord_bot.delete_application_command(app_cmd.id, server_id: server_id) 
      end
    end

    def initialize_commands(moduleconfig, controller)
      @log.info("Initializing module #{controller}")
      controller.commands(@log, moduleconfig).each do |command|
        @log.info("- Adding hook for command #{command.name}")

        @discord_bot.application_command(command.name) do |event|
          command.block.call(event)
        end
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
