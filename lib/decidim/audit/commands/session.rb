# frozen_string_literal: true

module Decidim
  module Audit
    module Commands
      class Session
        def self.wrap
          return yield if @session&.user

          @session = new(suppress_logs: true)
          @session.login
          return unless @session.user

          Decidim::Audit.with_actor(@session.user) do
            yield
          end
        ensure
          @session&.logout
          @session = nil
        end

        attr_reader :user

        def initialize(suppress_logs: false)
          @suppress_logs = suppress_logs
        end

        def login
          stdout.puts "To perform commands from the console, you need to login with a SYSTEM user."
          stdout.print "Email: "
          email = stdin.gets.strip
          stdout.puts email unless stdin.tty?
          stdout.print "Password: "
          password = stdin.tty? ? stdin.noecho(&:gets).strip : stdin.gets.strip
          stdout.puts ""

          suppress_logging { perform_login(email:, password:) }

          stdout.puts "Invalid email or password." unless user
        rescue Interrupt
          stdout.puts ""
          stdout.puts "Login interrupted."
        end

        def logout
          return unless @user

          suppress_logging { perform_logout }
        end

        private

        attr_reader :suppress_logs

        def perform_login(email:, password:)
          resource = Decidim::System::Admin.find_for_database_authentication(email:)

          Decidim::Audit.log(
            channel: "authentication",
            event: "console_attempt",
            resource:
          )

          return unless resource&.valid_password?(password)

          Decidim::Audit.log(
            channel: "authentication",
            event: "console_success",
            details: { scope: :admin },
            resource:
          )

          @user = resource
        end

        def perform_logout
          Decidim::Audit.log(
            channel: "authentication",
            event: "console_logout",
            details: { scope: :admin },
            resource: @user
          )

          @user = nil
        end

        def suppress_logging
          orig_level = ActiveRecord::Base.logger.level
          ActiveRecord::Base.logger.level = Logger::ERROR if suppress_logs && orig_level < Logger::ERROR
          yield
        ensure
          ActiveRecord::Base.logger.level = orig_level
        end

        def stdin
          self.class.const_get("STDIN")
        end

        def stdout
          self.class.const_get("STDOUT")
        end
      end
    end
  end
end
