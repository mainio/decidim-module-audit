# frozen_string_literal: true

require "spec_helper"

describe "OmniAuth" do
  let(:app) do
    lambda do |_env|
      [200, {}, ["Hello."]]
    end
  end
  let(:fresh_strategy) { Class.new(OmniAuth::Strategies::Test) }
  let(:instance) { fresh_strategy.new(app, name: "test") }

  let(:organization) { create(:organization) }
  let(:request_path) { "/users/auth/test" }
  let(:request_headers) do
    {
      "REMOTE_ADDR" => "1.2.3.4",
      "HTTP_CLIENT_IP" => "1.2.3.4",
      "HTTP_USER_AGENT" => "RSpec testing",
      "HTTP_SEC_CH_UA" => %("Not;A=Brand";v="1", "SomeBrand";v="2"),
      "HTTP_SEC_CH_UA_MOBILE" => "?0",
      "HTTP_SEC_CH_UA_PLATFORM" => %("Linux")
    }
  end
  let(:request) do
    ActionDispatch::Request.new(
      "HTTP_VERSION" => "1.1",
      "REQUEST_METHOD" => "POST",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded",
      "PATH_INFO" => request_path,
      "rack.input" => StringIO.new,
      "decidim.current_organization" => organization,
      **request_headers
    ).tap do |req|
      req.session = session

      # Set warden instance for the request as required by the request class
      Warden::Manager.new(app).call(req.env)
    end
  end
  let(:session) { ActionController::TestSession.new({}) }

  around do |example|
    OmniAuth.config.test_mode = true
    example.run
    OmniAuth.config.test_mode = false
  end

  before do
    allow(Decidim::Audit).to receive(:current_request).and_return(
      Decidim::Audit::Request.new(request)
    )
  end

  describe "before_request_phase" do
    subject { instance.call(request.env) }

    it "logs the login attempt" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.last
      expect(log.channel).to eq("authentication")
      expect(log.event).to eq("omniauth_attempt")
      expect(log.level).to eq("info")
      expect(log.details).to match("strategy" => "test")
      expect(log.resource).to be_nil
    end

    it_behaves_like "request details logging", channel: "authentication", event: "omniauth_attempt" do
      let(:expected_path) { request_path }

      before { subject }
    end
  end
end
