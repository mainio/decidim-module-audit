# frozen_string_literal: true

module Decidim
  module Audit
    module Api
      autoload :AuditTraceContext, "decidim/audit/api/audit_trace_context"
      autoload :AuditTracer, "decidim/audit/api/audit_tracer"
      autoload :SchemaExtension, "decidim/audit/api/schema_extension"
    end
  end
end
