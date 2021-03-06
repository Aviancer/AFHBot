module AFHBot

  module Group
    
    UNDEFINED_ROLE = 0x01
    UNCHANGED_ROLE = 0x02

    Results = Struct.new(:error, :success, :unchanged, :info) do
      def add_error(s)
        self.class.new(error + [s], success, unchanged, info)
      end
      def add_success(s)
        self.class.new(error, success + [s], unchanged, info)
      end
      def add_unchanged(s)
        self.class.new(error, success, unchanged + [s], info)
      end
      def add_info(s)
        self.class.new(error, success, unchanged, info + [s])
      end
    end

    def self.commands(log, moduleconfig)
      [
       AFHBot::Command.new(
         :listroles, 
         { :description => 'List available roles' }, 
         listroles(log, moduleconfig)),
       AFHBot::Command.new(
         :addrole, 
         { :description => '<role1> <role2..> Add role(s) for yourself',
           :usage => '!addrole <role1> <role2..>',
           :min_args => 1,
           :max_args => 20 }, 
         addrole(log, moduleconfig)),
       AFHBot::Command.new(
         :removerole, 
         { :description => '<role1> <role2..> Remove role(s) from yourself',
           :usage => '!removerole <role1> <role2..>',
           :min_args => 1,
           :max_args => 20 }, 
         removerole(log, moduleconfig) )
      ]
    end

    def self._permitcheck(moduleconfig, event)
      if moduleconfig.has_key?('chats_enabled') 
        return true if moduleconfig['chats_enabled'].has_key?('*') # Wildcard to allow for all chats.
        moduleconfig['chats_enabled'].detect { |name, channel| channel['id'] == event.channel.id }
      else
        false # Default to false if no ACL match
      end
    end

    def self._event2author(event)
      "#{event.author.name}##{event.author.discriminator}@#{event.channel.name}"
    end

    def self._logevent(log, method, event, level: :debug)
      # Max length willing to log of message is 512 characters.
      if event.message.content.length > 512
        message = event.message.content[0,512] + "..."
      else
        message = event.message.content
      end
      # send dynamically calls the method in log defined by 'level', eg. log.debug
      log.send(level, "AFHBot::Group::#{method} event: srv(#{event.channel.server.name}) src(#{_event2author(event)}) msg(#{message})")
    end

    def self._catcherror(log, method, event, msg, no_chat: false)
      log.error([msg, "-- Trace follows:"].join(" "))
       _logevent(log, method, event, level: :error)
       event << "Error: #{msg}" unless no_chat
    end

    def self._hasrole(moduleconfig, event, name)
      event.user.roles.detect { |r| r.id == moduleconfig['subscription_roles'][name]['id'] }
    end

    def self.listroles(log, moduleconfig)
      ->(event, *args) do # stabby lambda
        return nil unless _permitcheck(moduleconfig, event)
        _logevent(log, __method__, event)

        event << '[ Available subscription roles ]'
        event << '----------------------------------------------------'
        moduleconfig['subscription_roles'].each do |key, value|
          event << "#{key} | #{value['desc']}"
        end
        nil # Each lambda should return nil at the end.
      end
    end

    # Method is one of add_role or remove_role
    def self._role_commit(log, moduleconfig, event, method, role)
      unless moduleconfig['subscription_roles'].key?(role)
        log.info("User (#{_event2author(event)}) requested #{method} on non-existant role (#{role}).")
        return UNDEFINED_ROLE
      end
      user_hasrole = _hasrole(moduleconfig, event, role)
      return UNCHANGED_ROLE if method == 'add_role' and user_hasrole
      return UNCHANGED_ROLE if method == 'remove_role' and not user_hasrole

      begin
        event.user.send(method, moduleconfig['subscription_roles'][role]['id'])
      rescue RestClient::NotFound => e
        _catcherror(log, __method__, event, "Role(#{role}) not found on server or API went away (404 not found)", no_chat: true)
        return e
      rescue Discordrb::Errors::NoPermission => e
        _catcherror(log, __method__, event, "I don't have permissions to #{method} role(#{role}).", no_chat: true)
        return e
      end
      true
    end

    def self.addrole(log, moduleconfig)
      ->(event, *args) do
        return nil unless _permitcheck(moduleconfig, event)
        _logevent(log, __method__, event)

        results = args.uniq.reduce(Results.new([], [], [], [])) do |res, role| 
          status = _role_commit(log, moduleconfig, event, 'add_role', role) 
          case status
          when true
            res.add_success(role)
          when UNDEFINED_ROLE
            res.add_error(role)
          when UNCHANGED_ROLE
            res.add_unchanged(role)
          else
            res.add_error(role)
          end
        end

        if results.success.any?
          log.info("Added roles(#{results.success.join(",")}) for (#{_event2author(event)})")
          event << "Added roles(#{results.success.join(",")})." 
        end
          
        if results.error.any?
          event << "Got error when adding roles(#{results.error.join(",")})." 
        end

        if results.unchanged.any?
          event << "The following roles are unchanged (#{results.unchanged.join(",")})." 
        end
        nil
      end
    end

    def self.removerole(log, moduleconfig)
      ->(event, *args) do
        return nil unless _permitcheck(moduleconfig, event)
        _logevent(log, __method__, event)

        results = args.uniq.reduce(Results.new([], [], [], [])) do |res, role| 
          status = _role_commit(log, moduleconfig, event, 'remove_role', role) 
          case status
          when true
            res.add_success(role)
          when UNDEFINED_ROLE
            res.add_error(role)
          when UNCHANGED_ROLE
            res.add_unchanged(role)
          else
            res.add_error(role)
          end
        end

        if results.success.any?
          log.info("Removed roles(#{results.success.join(",")}) for (#{_event2author(event)})")
          event << "Removed roles(#{results.success.join(",")})." 
        end
          
        if results.error.any?
          event << "Got error when removing roles(#{results.error.join(",")})." 
        end

        if results.unchanged.any?
          event << "The following roles are unchanged (#{results.unchanged.join(",")})." 
        end
        nil
      end
    end

  end
end
