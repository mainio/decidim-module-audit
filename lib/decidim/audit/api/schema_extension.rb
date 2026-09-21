# frozen_string_literal: true

module Decidim
  module Audit
    module Api
      module SchemaExtension
        extend ActiveSupport::Concern

        included do
          trace_with(AuditTracer)
        end
      end
    end
  end
end
