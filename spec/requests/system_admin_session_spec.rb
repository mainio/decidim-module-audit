# frozen_string_literal: true

require "spec_helper"

describe "SystemAdminSession" do
  subject { response.body }

  let(:sign_in_path) { Decidim::System::Engine.routes.url_helpers.admin_session_path }
  let(:sign_out_path) { Decidim::System::Engine.routes.url_helpers.destroy_admin_session_path }

  let(:email) { "system.admin@example.org" }
  let(:password) { "decidim123456789" }
  let!(:user) { create(:admin, email:, password:) }
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

  context "with unsuccessful login attempt" do
    it_behaves_like "request details logging", channel: "authentication", event: "attempt" do
      let(:expected_path) { "/system/admins/sign_in" }

      before { perform_login_attempt(email:, password: "invalid") }
    end
    it_behaves_like "request details logging", channel: "authentication", event: "failure" do
      let(:expected_path) { "/system/unauthenticated" }

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
        "scope" => "admin",
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
      let(:expected_path) { "/system/admins/sign_in" }

      before { perform_login_attempt(email:, password:) }
    end
    it_behaves_like "request details logging", channel: "authentication", event: "success" do
      let(:expected_path) { "/system/admins/sign_in" }

      before { perform_login_attempt(email:, password:) }
    end

    it "logs the attempt with correct details" do
      expect { perform_login_attempt(email:, password:) }.to change(Decidim::Audit::Log, :count).by(2)

      expect(Decidim::Audit::Log.where(channel: "authentication", event: "attempt").count).to eq(1)
      expect(Decidim::Audit::Log.where(channel: "authentication", event: "success").count).to eq(1)

      log = Decidim::Audit::Log.find_by(channel: "authentication", event: "attempt")
      expect(log.level).to eq("info")
      expect(log.resource).to eq(user)
    end

    it "logs the successful login" do
      perform_login_attempt(email:, password:)

      expect(Decidim::Audit::Log.where(channel: "authentication", event: "attempt").count).to eq(1)
      expect(Decidim::Audit::Log.where(channel: "authentication", event: "success").count).to eq(1)

      log = Decidim::Audit::Log.find_by(channel: "authentication", event: "success")
      expect(log.level).to eq("info")
      expect(log.resource).to eq(user)
    end
  end

  context "when logging out" do
    before do
      login_as user, scope: :admin

      # Do the initial request as the signed in user to add the initial
      # successful authentication log entry. Otherwise it would be logged during
      # the next request.
      get("/", params: { locale: I18n.default_locale })
    end

    it_behaves_like "request details logging", channel: "authentication", event: "logout" do
      let(:expected_method) { "DELETE" }
      let(:expected_path) { sign_out_path }

      before { perform_logout_request }
    end

    it "logs the logout request" do
      expect { perform_logout_request }.to change(Decidim::Audit::Log, :count).by(1)

      expect(Decidim::Audit::Log.where(channel: "authentication", event: "logout").count).to eq(1)

      log = Decidim::Audit::Log.find_by(channel: "authentication", event: "logout")
      expect(log.level).to eq("info")
      expect(log.details).to match("scope" => "admin")
      expect(log.resource).to eq(user)
    end
  end

  def perform_login_attempt(email:, password:)
    post(
      sign_in_path,
      params: { locale: I18n.default_locale, admin: { email:, password: } },
      headers: request_headers
    )
  end

  def perform_logout_request
    delete(sign_out_path, params: { locale: I18n.default_locale }, headers: request_headers)
  end
end
