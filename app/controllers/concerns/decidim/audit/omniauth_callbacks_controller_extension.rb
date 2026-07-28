# frozen_string_literal: true

module Decidim
  module Audit
    module OmniauthCallbacksControllerExtension
      extend ActiveSupport::Concern

      included do
        before_action :audit_log_failure, only: [:failure] # rubocop:disable Rails/LexicallyScopedActionFilter
      end

      private

      def audit_log_failure
        exception = request.get_header("omniauth.error")
        reason = exception.error_reason if exception.respond_to?(:error_reason)
        reason ||= exception.error if exception.respond_to?(:error)
        reason ||= exception.message if exception.message != exception.class.name

        type = request.get_header("omniauth.error.type")
        strategy_name = failed_strategy.options.name

        Decidim::Audit.log(
          channel: "authentication",
          event: "omniauth_failure",
          level: :notice,
          message: type,
          details: {
            strategy: strategy_name,
            error: exception.class.name,
            reason:
          }
        )
      end
    end
  end
end
