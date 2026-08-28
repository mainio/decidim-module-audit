# frozen_string_literal: true

module Decidim
  module Audit
    module AuthorizationWorkflowAdminControllerExtension
      extend ActiveSupport::Concern

      included do
        around_action :audit_read, if: -> { request.method == "GET" }
      end

      class_methods do
        def audit_workflow_name(name = nil)
          @audit_workflow_name = name if name
          @audit_workflow_name
        end
      end

      private

      def audit_read
        Decidim::Audit.log(
          channel: "authorizations_admin",
          event: action_name,
          details: { workflow: self.class.audit_workflow_name }.compact,
          level: :info
        )

        event = action_name.to_sym == :index ? :read_list : :read
        Auditable.audit_read_multiple(
          event,
          Decidim::User,
          Decidim::Authorization
        ) { yield }
      end
    end
  end
end
