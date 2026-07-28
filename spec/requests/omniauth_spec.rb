# frozen_string_literal: true

require "spec_helper"

module Decidim::Dev
  # This controller simulates a customized Omniauth callback flow that would be
  # used by 3rd party login providers. Such providers may need to customize how
  # the login callback is handled based on conditions returned by the Omniauth
  # provider. Customizing the Omniauth strategy is not enough when the login
  # provider needs access to the Decidim context.
  class OmniauthCallbacksController < Decidim::Devise::OmniauthRegistrationsController
    def dev_callback
      create
    end
  end
end

describe "Omniauth" do
  subject { response.body }

  let(:organization) { create(:organization) }

  let(:email) { "user@example.org" }
  let(:name) { "Custom Auth" }
  let(:nickname) { "custom_auth" }

  around do |example|
    # Silence the Omniauth logging during testing
    original_logger = OmniAuth.config.logger
    OmniAuth.config.logger = Logger.new(StringIO.new)

    host! organization.host

    example.run

    OmniAuth.config.logger = original_logger
  end

  describe "POST request" do
    let(:request_path) { "/users/auth/test" }

    it_behaves_like "request details logging", channel: "authentication", event: "omniauth_attempt" do
      let(:expected_path) { request_path }
      let(:request_headers) do
        {
          "REMOTE_ADDR" => "10.0.0.1",
          "HTTP_CLIENT_IP" => "1.2.3.4",
          "HTTP_USER_AGENT" => "RSpec testing",
          "HTTP_SEC_CH_UA" => %("Not;A=Brand";v="1", "SomeBrand";v="2"),
          "HTTP_SEC_CH_UA_MOBILE" => "?0",
          "HTTP_SEC_CH_UA_PLATFORM" => %("Linux")
        }
      end

      before { post(request_path, headers: request_headers, params: { locale: I18n.default_locale }) }
    end

    it "logs the login attempt" do
      expect { post(request_path, params: { locale: I18n.default_locale }) }.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.find_by(channel: "authentication", event: "omniauth_attempt")
      expect(log.level).to eq("info")
      expect(log.details).to match("strategy" => "test")
    end
  end

  describe "GET callback" do
    let(:callback_path) { "/users/auth/test/callback" }

    it_behaves_like "request details logging", channel: "authentication", event: "success" do
      let(:expected_method) { "GET" }
      let(:expected_path) { callback_path }
      let(:request_headers) do
        {
          "REMOTE_ADDR" => "10.0.0.1",
          "HTTP_CLIENT_IP" => "1.2.3.4",
          "HTTP_USER_AGENT" => "RSpec testing",
          "HTTP_SEC_CH_UA" => %("Not;A=Brand";v="1", "SomeBrand";v="2"),
          "HTTP_SEC_CH_UA_MOBILE" => "?0",
          "HTTP_SEC_CH_UA_PLATFORM" => %("Linux")
        }
      end

      before { get(callback_path, params: { locale: I18n.default_locale, name:, nickname:, email: }, headers: request_headers) }
    end

    context "with a new user" do
      # The name is set to empty string to display the Omniauth registration
      # form after a successful authentication.
      #
      # After update to v0.30.0, this can be dropped.
      # See: https://github.com/decidim/decidim/pull/13077
      let(:name) { "" }

      let(:oauth_signature) { Decidim::OmniauthRegistrationForm.create_signature("test", email) }

      it "shows the login form" do
        # The login only happens after the registration is completed and the
        # form is submitted with valid details.
        expect { get(callback_path, params: { locale: I18n.default_locale, name:, nickname:, email: }) }.not_to change(Decidim::Audit::Log, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Create an account")
        expect(response.body).to include("Terms of Service")
      end

      it "logs the successful login" do
        get(callback_path, params: { locale: I18n.default_locale, name:, nickname:, email: })

        expect(response).to have_http_status(:ok)

        # This is needed in order for the account to be logged in straight after
        # submitting the form. Otherwise the login only happens after the email
        # is verified as another separate step.
        #
        # After update to v0.30.0, this can be dropped.
        # See: https://github.com/decidim/decidim/pull/13077
        allow_any_instance_of(Decidim::Devise::OmniauthRegistrationsController).to receive(:verified_email).and_return(email) # rubocop:disable RSpec/AnyInstance

        expect do
          post(
            "/omniauth_registrations.user",
            params: {
              locale: I18n.default_locale,
              user: {
                uid: email,
                provider: "test",
                oauth_signature:,
                name: "Custom Auth",
                nickname:,
                email:
              }
            }
          )
        end.to change(Decidim::Audit::Log, :count).by(3)

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(decidim.root_path)

        expect(Decidim::Audit::Log.where(channel: "decidim_users", event: "create").count).to eq(1)
        expect(Decidim::Audit::Log.where(channel: "decidim_users", event: "update").count).to eq(1)
        expect(Decidim::Audit::Log.where(channel: "authentication", event: "success").count).to eq(1)

        log = Decidim::Audit::Log.find_by(channel: "authentication", event: "success")
        expect(log.level).to eq("info")
        expect(log.details).to match("scope" => "user")
        expect(log.resource).to eq(Decidim::User.find_by(email:))
      end
    end

    context "with existing user" do
      let!(:user) { create(:user, :confirmed, organization:, email:) }

      it "logs the successful login" do
        expect { get(callback_path, params: { locale: I18n.default_locale, name:, nickname:, email: }) }.to change(Decidim::Audit::Log, :count).by(2)

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(decidim.root_path)

        expect(Decidim::Audit::Log.where(channel: "decidim_users", event: "update").count).to eq(1)
        expect(Decidim::Audit::Log.where(channel: "authentication", event: "success").count).to eq(1)

        log = Decidim::Audit::Log.find_by(channel: "authentication", event: "success")
        expect(log.level).to eq("info")
        expect(log.details).to match("scope" => "user")
        expect(log.resource).to eq(Decidim::User.find_by(email:))
      end
    end

    context "with failed login" do
      let(:fail_key) { "timeout" }
      let(:fail_message) { "The login attempt has timed out." }

      it "logs the failed login attempt" do
        expect { get(callback_path, params: { locale: I18n.default_locale, fail: "1", fail_key:, fail_message: }) }.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.find_by(channel: "authentication", event: "omniauth_failure")
        expect(log.level).to eq("notice")
        expect(log.message).to eq(fail_key)
        expect(log.details).to match(
          "strategy" => "test",
          "error" => "OmniAuth::Strategies::Test::CallbackError",
          "reason" => fail_message
        )
      end
    end
  end
end
