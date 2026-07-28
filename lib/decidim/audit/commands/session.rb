# frozen_string_literal: true

module Decidim
  module Audit
    module Commands
      class Session
        def self.wrap
          return yield if @session&.user

          @session = new
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

        def login
          stdout.puts "To perform commands from the console, you need to login with a SYSTEM user."
          stdout.print "Email: "
          email = stdin.gets.strip
          stdout.puts email unless stdin.tty?
          stdout.print "Password: "
          password = stdin.tty? ? stdin.noecho(&:gets).strip : stdin.gets.strip
          stdout.puts ""

          resource = Decidim::System::Admin.find_for_database_authentication(email:)

          Decidim::Audit.log(
            channel: "authentication",
            event: "console_attempt",
            resource:
          )

          unless resource&.valid_password?(password)
            stdout.puts "Invalid email or password."
            return
          end

          Decidim::Audit.log(
            channel: "authentication",
            event: "console_success",
            details: { scope: :admin },
            resource:
          )

          @user = resource
        rescue Interrupt
          stdout.puts ""
          stdout.puts "Login interrupted."
        end

        def logout
          return unless @user

          Decidim::Audit.log(
            channel: "authentication",
            event: "console_logout",
            details: { scope: :admin },
            resource: @user
          )

          @user = nil
        end

        private

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
