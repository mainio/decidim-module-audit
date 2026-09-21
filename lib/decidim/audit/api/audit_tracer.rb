# frozen_string_literal: true

module Decidim
  module Audit
    module Api
      module AuditTracer
        def parse(query_string:)
          super
        rescue StandardError => e
          audit_context&.trace_parse_error(e)
          raise
        end

        def validate(query:, validate:)
          data = super
          errors = data[:errors]

          audit_context&.trace_validate_errors(errors) if errors.any?

          data
        end

        def execute_query(query:)
          result = super

          audit_context&.trace_execution_errors(query.context.errors) if query.context.errors.any?

          result
        end

        private

        def audit_context
          AuditTraceContext.current&.value
        end
      end
    end
  end
end
