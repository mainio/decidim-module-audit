# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Middleware::AuditContext do
  subject(:middleware) { described_class.new(app) }

  let(:app) { ->(env) { [200, env, "app"] } }
  let(:env) { Rack::MockRequest.env_for("https://example.org", {}) }

  describe "#call" do
    subject { middleware.call(env) }

    it "sets the current request" do
      expect(app).to receive(:call) do
        expect(Decidim::Audit.current_request).to be_a(Decidim::Audit::Request)
      end

      subject

      expect(Decidim::Audit.current_request).to be_nil
    end

    context "when the request has already been set by another thread" do
      it "does not set the current request again" do
        first_called = false
        second_called = false
        first_request = nil
        second_request = nil

        expect(app).to receive(:call).twice do |app_env|
          if app_env["first_request_active"] == true && first_called != true
            first_called = true
            first_request = Decidim::Audit.current_request
          end
          if app_env["second_request_active"] == true && second_called != true
            second_called = true
            second_request = Decidim::Audit.current_request
          end
          sleep 2 unless second_called
        end

        first_thread = Thread.new do
          env["first_request_active"] = true
          middleware.call(env)
          env.delete("first_request_active")
        end
        second_thread = Thread.new do
          sleep 1
          env["second_request_active"] = true
          middleware.call(env)
          env.delete("second_request_active")
        end

        second_thread.join
        first_thread.join

        expect(first_called).to be(true)
        expect(second_called).to be(true)
        expect(Decidim::Audit.current_request).to be_nil

        expect(first_request).not_to be(second_request)
      end
    end
  end
end
