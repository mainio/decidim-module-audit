# frozen_string_literal: true

module Decidim
  module Audit
    # Adds a hook to the login attempts to add them to the audit log. This works
    # both for regular user logins as well as API user logins for versions
    # 0.31.0 and above.
    module SessionsControllerExtension
      extend ActiveSupport::Concern

      included do
        before_action :audit_log_attempt, only: [:create] # rubocop:disable Rails/LexicallyScopedActionFilter
      end

      private

      def audit_log_attempt
        auth_params = sign_in_params

        auth_keys = resource_class.authentication_keys
        auth_keys = auth_keys.keys if auth_keys.respond_to?(:keys)
        resource_params = auth_params.slice(*auth_keys)
        resource_params.merge!(env: { "decidim.current_organization" => current_organization }.compact.presence)
        resource_params.compact!

        # With the API users in v0.31.0 and above, the authentication keys
        # contain both `key` and `secret` but if we want to log the resource for
        # the authentication attempt, the resource should be searched for using
        # only the "username" (i.e. the `key`) of the record.
        resource_params.slice!(:secret) if resource_name == :api_user

        mapping = ::Devise.mappings[resource_name]
        resource = mapping.to.find_for_database_authentication(resource_params)

        Decidim::Audit.log(
          channel: "authentication",
          event: "attempt",
          resource:
        )
      end
    end
  end
end
