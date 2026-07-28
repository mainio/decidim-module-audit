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
        resource = Decidim::User.find_by(email: sign_in_params[:email])

        Decidim::Audit.log(
          channel: "authentication",
          event: "attempt",
          resource:
        )
      end
    end
  end
end
