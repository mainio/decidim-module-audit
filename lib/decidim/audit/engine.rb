# frozen_string_literal: true

require "rails"
require "decidim/core"
require "decidim/audit/middleware/audit_context"

module Decidim
  module Audit
    # This is the engine that runs on the public interface of the module.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::Audit

      initializer "decidim_audit.omniauth_hooks", after: "build_middleware_stack" do
        override_omniauth_hook(:before_request_phase) do |env|
          strategy = env["omniauth.strategy"]
          strategy_name = strategy.options.name

          Decidim::Audit.log(
            channel: "authentication",
            event: "omniauth_attempt",
            details: { strategy: strategy_name }
          )
        end
      end

      initializer "decidim_audit.add_customizations", before: "add_routing_paths" do
        config.to_prepare do
          # Controllers
          ::Devise::SessionsController.include(SessionsControllerExtension)
          ::Devise::OmniauthCallbacksController.include(OmniauthCallbacksControllerExtension)

          # Models
          ::Decidim::User.include(Auditable)
          ::Decidim::System::Admin.include(Auditable) if Decidim.module_installed?(:system)
          ::Decidim::Authorization.class_eval do
            include(Auditable)

            # Do not store the potentially sensitive attributes for
            # authorizations (even when encrypted) because these details may
            # have specific requirements for their retention periods and the
            # audit logs would have to be destroyed also when the data is
            # destroyed.
            exclude_auditable_attributes! :metadata, :verification_metadata
          end
        end
      end

      initializer "decidim_audit.middleware", before: "decidim_core.middleware" do |app|
        app.config.middleware.insert_before Warden::Manager, Decidim::Audit::Middleware::AuditContext
      end

      initializer "decidim_audit.gid_locator", after: "global_id" do
        GlobalID::Locator.use :"decidim-audit-module" do |gid, options|
          module_classes = [
            Decidim::Audit::Actor::Visitor,
            Decidim::Audit::Actor::SystemUser
          ]
          if module_classes.include?(gid.model_class)
            gid.model_class.find(gid.model_id, gid.params)
          else
            # Default to normal locator for unrecognized classes.
            gid.uri.host = Rails.application.railtie_name.remove("_application").dasherize
            GlobalID::Locator.locate(gid, options)
          end
        end
      end

      console do |app|
        require "decidim/audit/commands/irb_console_extension"

        if app.config.console
          app.config.console.include(Decidim::Audit::Commands::IRBConsoleExtension)
        elsif Gem::Version.new(Rails.version) < Gem::Version.new("7.2.0")
          require "irb"
          IRB.include(Decidim::Audit::Commands::IRBConsoleExtension)
        else
          # Rails 7.2.0 ->
          require "rails/commands/console/irb_console"
          Rails::Console::IRBConsole.include(Decidim::Audit::Commands::IRBConsoleExtension)
        end
      end

      runner do
        require "decidim/audit/commands/runner_command_extension"
        Rails::Command::RunnerCommand.include(Decidim::Audit::Commands::RunnerCommandExtension)
      end

      private

      def override_omniauth_hook(name)
        original = OmniAuth.config.send(name)
        OmniAuth.config.send(
          :"#{name}=",
          lambda do |env|
            yield env
            original&.call(env)
          end
        )
      end
    end
  end
end
