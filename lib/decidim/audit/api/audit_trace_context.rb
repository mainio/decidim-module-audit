# frozen_string_literal: true

module Decidim
  module Audit
    module Api
      class AuditTraceContext
        class << self
          def wrap
            context = new
            current.bind(context) { yield }
            context
          end

          def current
            @current ||= Concurrent::LockLocalVar.new
          end
        end

        def log_errors
          type, errors =
            if @parse_error.present?
              [:parse_error, [@parse_error]]
            elsif @validation_errors.present?
              [:validation_error, @validation_errors]
            elsif @execution_errors.present?
              [:execution_error, @execution_errors]
            end
          return unless type

          Decidim::Audit.log(
            channel: "api_query",
            event: :error,
            level: :error,
            message: type,
            details: {
              errors: errors.map { |err| err.class.name },
              messages: errors.map(&:message)
            }
          )
        end

        def trace_parse_error(error)
          @parse_error = error
        end

        def trace_validate_errors(errors)
          @validation_errors = errors
        end

        def trace_execution_errors(errors)
          @execution_errors = errors
        end
      end
    end
  end
end
