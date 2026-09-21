# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Api::AuditTracer do
  let(:schema) do
    qry = query
    tracer = described_class
    Class.new(GraphQL::Schema) do
      query(qry)
      trace_with(tracer)
    end
  end
  let(:query) do
    Class.new(GraphQL::Schema::Object) do
      graphql_name "Foobar"

      field :int, Integer, null: false
      field :error, String, null: false

      def int
        1
      end

      def error
        raise GraphQL::ExecutionError, "Not implemented"
      end
    end
  end
  let(:trace_context) { Decidim::Audit::Api::AuditTraceContext.new }

  around do |example|
    Decidim::Audit::Api::AuditTraceContext.current.bind(trace_context) { example.run }
  end

  context "with an incorrectly formed query" do
    it "traces a parse error" do
      expect(trace_context).to receive(:trace_parse_error).and_call_original
      expect(trace_context).not_to receive(:trace_validate_errors)
      expect(trace_context).not_to receive(:trace_execution_errors)

      schema.execute(%({ int(value: "2) }))
      expect do
        trace_context.log_errors
      end.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.order(:id).last
      expect(log.channel).to eq("api_query")
      expect(log.level).to eq("error")
      expect(log.event).to eq("error")
      expect(log.message).to eq("parse_error")
      expect(log.details["errors"]).to eq(["GraphQL::ParseError"])
    end
  end

  context "with an invalid query" do
    it "traces a parse error" do
      expect(trace_context).not_to receive(:trace_parse_error)
      expect(trace_context).to receive(:trace_validate_errors).and_call_original
      expect(trace_context).not_to receive(:trace_execution_errors)

      schema.execute(%({ foobar }))
      expect do
        trace_context.log_errors
      end.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.order(:id).last
      expect(log.channel).to eq("api_query")
      expect(log.level).to eq("error")
      expect(log.event).to eq("error")
      expect(log.message).to eq("validation_error")
      expect(log.details["errors"]).to eq(["GraphQL::StaticValidation::FieldsAreDefinedOnTypeError"])
    end
  end

  context "with an execution error" do
    it "traces a parse error" do
      expect(trace_context).not_to receive(:trace_parse_error)
      expect(trace_context).not_to receive(:trace_validate_errors)
      expect(trace_context).to receive(:trace_execution_errors).and_call_original

      schema.execute(%({ error }))
      expect do
        trace_context.log_errors
      end.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.order(:id).last
      expect(log.channel).to eq("api_query")
      expect(log.level).to eq("error")
      expect(log.event).to eq("error")
      expect(log.message).to eq("execution_error")
      expect(log.details["errors"]).to eq(["GraphQL::ExecutionError"])
    end
  end
end
