# frozen_string_literal: true

require "spec_helper"

describe "Session" do
  subject { response.body }

  let(:sign_in_path) { Decidim::Core::Engine.routes.url_helpers.user_session_path }
  let(:sign_out_path) { Decidim::Core::Engine.routes.url_helpers.destroy_user_session_path }

  let(:organization) { create(:organization) }
  let(:email) { "user@example.org" }
  let(:password) { "decidim123456789" }
  let!(:user) { create(:user, :confirmed, email:, password:, organization:) }
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

  before do
    host! organization.host
  end

  context "with unsuccessful login attempt" do
    it_behaves_like "request details logging", channel: "authentication", event: "attempt" do
      before { perform_login_attempt(email:, password: "invalid") }
    end
    it_behaves_like "request details logging", channel: "authentication", event: "failure" do
      let(:expected_path) { "/unauthenticated" }

      before { perform_login_attempt(email:, password: "invalid") }
    end

    it "logs the attempt with correct details" do
      expect { perform_login_attempt(email:, password: "invalid") }.to change(Decidim::Audit::Log, :count).by(2)

      expect(Decidim::Audit::Log.where(channel: "authentication", event: "attempt").count).to eq(1)
      expect(Decidim::Audit::Log.where(channel: "authentication", event: "failure").count).to eq(1)

      log = Decidim::Audit::Log.find_by(channel: "authentication", event: "attempt")
      expect(log.level).to eq("info")
      expect(log.resource).to eq(user)
    end

    it "logs the failed login" do
      perform_login_attempt(email:, password: "invalid")

      expect(Decidim::Audit::Log.where(channel: "authentication", event: "attempt").count).to eq(1)
      expect(Decidim::Audit::Log.where(channel: "authentication", event: "failure").count).to eq(1)

      log = Decidim::Audit::Log.find_by(channel: "authentication", event: "failure")
      expect(log.level).to eq("notice")
      expect(log.message).to eq("invalid")
      expect(log.details).to eq(
        "path" => sign_in_path,
        "scope" => "user",
        "action" => "unauthenticated"
      )
    end

    context "when the email does not exist" do
      it "does not map the resource" do
        expect { perform_login_attempt(email: "unexisting@example.org", password:) }.to change(Decidim::Audit::Log, :count).by(2)

        log = Decidim::Audit::Log.find_by(channel: "authentication", event: "attempt")
        expect(log.resource).to be_nil

        log = Decidim::Audit::Log.find_by(channel: "authentication", event: "failure")
        expect(log.resource).to be_nil
      end
    end
  end

  context "with successful login attempt" do
    it_behaves_like "request details logging", channel: "authentication", event: "attempt" do
      before { perform_login_attempt(email:, password:) }
    end
    it_behaves_like "request details logging", channel: "authentication", event: "success" do
      before { perform_login_attempt(email:, password:) }
    end

    it "logs the attempt with correct details" do
      expect { perform_login_attempt(email:, password:) }.to change(Decidim::Audit::Log, :count).by(3)

      expect(Decidim::Audit::Log.where(channel: "authentication", event: "attempt").count).to eq(1)
      expect(Decidim::Audit::Log.where(channel: "authentication", event: "success").count).to eq(1)
      expect(Decidim::Audit::Log.where(channel: "decidim_users", event: "update").count).to eq(1)

      log = Decidim::Audit::Log.find_by(channel: "authentication", event: "attempt")
      expect(log.level).to eq("info")
      expect(log.resource).to eq(user)
    end

    it "logs the successful login" do
      perform_login_attempt(email:, password:)

      expect(Decidim::Audit::Log.where(channel: "authentication", event: "attempt").count).to eq(1)
      expect(Decidim::Audit::Log.where(channel: "authentication", event: "success").count).to eq(1)
      expect(Decidim::Audit::Log.where(channel: "decidim_users", event: "update").count).to eq(1)

      log = Decidim::Audit::Log.find_by(channel: "authentication", event: "success")
      expect(log.level).to eq("info")
      expect(log.resource).to eq(user)
    end
  end

  context "when logging out" do
    before do
      login_as user, scope: :user

      # Do the initial request as the signed in user to add the initial
      # successful authentication log entry. Otherwise it would be logged during
      # the next request.
      get("/", params: { locale: I18n.default_locale }, headers: { "HOST" => organization.host })
    end

    it_behaves_like "request details logging", channel: "authentication", event: "logout" do
      let(:expected_method) { "DELETE" }
      let(:expected_path) { sign_out_path }

      before { perform_logout_request }
    end

    it "logs the logout request" do
      expect { perform_logout_request }.to change(Decidim::Audit::Log, :count).by(2)

      expect(Decidim::Audit::Log.where(channel: "authentication", event: "logout").count).to eq(1)
      # The first record is for updating the actual record details during login
      # (devise/trackable) and the second record is for invalidating all
      # sessions (decidim/user).
      expect(Decidim::Audit::Log.where(channel: "decidim_users", event: "update").count).to eq(2)

      log = Decidim::Audit::Log.find_by(channel: "authentication", event: "logout")
      expect(log.level).to eq("info")
      expect(log.details).to match("scope" => "user")
      expect(log.resource).to eq(user)
    end
  end

  def perform_login_attempt(email:, password:)
    post(
      sign_in_path,
      params: { locale: I18n.default_locale, user: { email:, password: } },
      headers: request_headers
    )
  end

  def perform_logout_request
    delete(sign_out_path, params: { locale: I18n.default_locale }, headers: request_headers)
  end
end
