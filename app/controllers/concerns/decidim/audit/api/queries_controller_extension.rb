# frozen_string_literal: true

module Decidim
  module Audit
    module Api
      # Audits the API queries done to the GraphQL API.
      module QueriesControllerExtension
        extend ActiveSupport::Concern

        included do
          around_action :audit_query, only: [:create] # rubocop:disable Rails/LexicallyScopedActionFilter
        end

        private

        def audit_query
          Decidim::Audit.log(
            channel: "api_query",
            event: "execute",
            message: params[:query],
            details: {
              variables: params[:variables],
              operation_name: params[:operationName]
            }.compact,
            level: :info
          )

          trace = AuditTraceContext.wrap do
            Decidim::User.audit_read(:api) do
              yield
            end
          end
          trace.log_errors
        end
      end
    end
  end
end
