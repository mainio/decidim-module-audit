# frozen_string_literal: true

require "spec_helper"

describe "Warden" do
  let(:manager) { Warden::Manager }
  let(:valid_response) { Rack::Response.new("OK").finish }
  let(:failure_app) do
    ->(_env) { [401, { "Content-Type" => "text/plain" }, ["Failure!"]] }
  end
  let(:session_class) do
    Class.new do
      attr_accessor :app

      def initialize(app, _configs = {})
        @app = app
      end

      def call(env)
        env["rack.session"] ||= {}
        @app.call(env)
      end
    end
  end

  let(:app) do
    lambda do |env|
      env["warden"].authenticate!(scope: :user, locale: I18n.locale)
      valid_response
    end
  end
  let(:env) do
    env_with_params(params:)
  end
  let(:params) do
    { "user[email]" => user.email, "user[password]" => provided_password }
  end

  let(:organization) { create(:organization) }
  let!(:user) { create(:user, :confirmed, organization:, password:) }
  let(:password) { "decidim123456789" }
  let(:provided_password) { password }

  describe "after_authentication" do
    it "logs a successful authentication" do
      expect { setup_rack(app).call(env) }.to change(Decidim::Audit::Log, :count).by(2)

      expect(Decidim::Audit::Log.where(channel: "authentication", event: "success").count).to eq(1)
      expect(Decidim::Audit::Log.where(channel: "decidim_users", event: "update").count).to eq(1)

      log = Decidim::Audit::Log.where(channel: "authentication").last
      expect(log.channel).to eq("authentication")
      expect(log.event).to eq("success")
      expect(log.level).to eq("info")
      expect(log.details).to match("scope" => "user")
      expect(log.resource).to eq(user)
    end
  end

  describe "before_failure" do
    let(:provided_password) { "invalid" }

    it "logs a failed authentication" do
      expect { setup_rack(app).call(env) }.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.where(channel: "authentication").last
      expect(log.channel).to eq("authentication")
      expect(log.event).to eq("failure")
      expect(log.level).to eq("notice")
      expect(log.message).to eq("invalid")
      expect(log.details).to match(
        "path" => "/?#{params.to_query}",
        "scope" => "user",
        "action" => "unauthenticated"
      )
      expect(log.resource).to eq(user)
    end
  end

  describe "before_logout" do
    let(:request) { Decidim::Audit::Request.new(rack_request) }
    let(:rack_request) { ActionDispatch::Request.new(env) }
    let(:visitor) { build(:audit_visitor) }

    before do
      allow(Decidim::Audit).to receive(:current_request).and_return(request)
      allow(request).to receive(:visitor).and_return(visitor)
    end

    it "logs a logout" do
      setup_rack(app).call(env)

      expect { env["warden"].logout(:user) }.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.where(channel: "authentication").last
      expect(log.channel).to eq("authentication")
      expect(log.event).to eq("logout")
      expect(log.level).to eq("info")
      expect(log.details).to match("scope" => "user")
      expect(log.resource).to eq(user)
      expect(log.actor_type).to eq("visitor")
      expect(log.actor).to eq(visitor)
    end
  end

  # The helper methods are originally from:
  # https://github.com/wardencommunity/warden/blob/master/spec/helpers/request_helper.rb
  def setup_rack(app = nil, opts = {}, &block)
    app ||= block if block_given?

    opts[:failure_app] ||= failure_app
    opts[:default_strategies] ||= [:database_authenticatable]
    opts[:default_serializers] ||= [:session]
    blk = opts[:configurator] || proc {}

    default_session = session_class
    Rack::Builder.new do
      use opts[:session] || default_session unless opts[:nil_session]
      use Warden::Manager, opts, &blk
      run app
    end
  end

  def env_with_params(path: "/", params: {}, env: {})
    method = params.delete(:method) || "GET"
    env = {
      "HTTP_VERSION" => "1.1",
      "REQUEST_METHOD" => method.to_s,
      "devise.allow_params_authentication" => true,
      "decidim.current_organization" => organization
    }.merge(env)
    Rack::MockRequest.env_for("#{path}?#{Rack::Utils.build_query(params)}", env)
  end
end
