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

          ControllerAuditUserRead.configure do
            audit_controller Decidim::Admin::UsersController, actions: :index
            audit_controller Decidim::Admin::OfficializationsController
            audit_controller Decidim::Admin::ImpersonatableUsersController
            audit_controller Decidim::Admin::ConflictsController
            audit_controller Decidim::Admin::ManagedUsers::ImpersonationLogsController
            audit_controller Decidim::Admin::ManagedUsers::PromotionsController
            audit_controller Decidim::Admin::ParticipatorySpace::UserRoleController
            audit_controller Decidim::Admin::DashboardController, actions: :show, events: { show: :read_list }
            audit_controller Decidim::Admin::LogsController

            # ENABLE THIS AFTER THE FOLLOWING PR IS RELEASED:
            # https://github.com/decidim/decidim/pull/17558
            #
            # This can be enabled after the optimized conversation fetching is
            # implemented and merged to the core. When enabling, remove
            # AdminReportsControllerExtension.
            #
            # audit_controller Decidim::Admin::Moderations::ReportsController, actions: :index, events: { index: :read }
          end

          # REMOVE THIS AFTER THE FOLLOWING PR IS RELEASED:
          # https://github.com/decidim/decidim/pull/17558
          #
          # After removed, enable the commented `audit_controller` call above
          # for the same controller.
          #
          # See AdminReportsControllerExtension for further information.
          Decidim::Admin::Moderations::ReportsController.include(AdminReportsControllerExtension)

          # Models
          ::Decidim::UserBaseEntity.include(Auditable)
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

      # Finds all configured authorization workflows and adds audit to their
      # admin controllers. Note that for the user-facing controllers do not need
      # additional auditing because they manage changes for the authorization
      # records which is already audited. The extra admin-level audit is needed
      # because someone else (i.e. an admin user) is typically managing the
      # records in these cases when these actions need to be logged.
      initializer "decidim_audit.authorization_workflows_audit" do
        # After Rails 7.1 this can be changed the following:
        # config.after_routes_loaded do
        #   # (move the code here from extend_admin_workflow_controllers)
        # end
        engine = self
        config.to_prepare do
          engine.send(:extend_admin_workflow_controllers)
        end
      end
      # After Rails 7.1 and the above change, this can be removed. This is
      # needed because the routes would not be defined on the first run of the
      # `to_prepare` block above.
      Rails::Application::Finisher.initializer :decidim_audit_authorization_workflows, after: :set_routes_reloader_hook do
        Decidim::Audit::Engine.instance.send(:extend_admin_workflow_controllers)
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

      def extend_admin_workflow_controllers
        return unless Decidim.respond_to?(:authorization_workflows)

        engines = Decidim.authorization_workflows.to_h do |workflow|
          [workflow.name, workflow.admin_engine]
        end.compact
        engines.each do |workflow_name, engine|
          controllers = engine.routes.set.map do |route|
            "#{route.defaults[:controller].underscore.camelize}Controller"
          end.uniq

          controllers.each do |controller_name|
            controller = controller_name.constantize
            controller.include(AuthorizationWorkflowAdminControllerExtension)
            controller.audit_workflow_name(workflow_name)
          rescue NameError => e
            Rails.logger.warn("[AUDIT] Authorization workflow admin controller not found: #{e.name}. This controller is not audited.")
          end
        end
      end
    end
  end
end
