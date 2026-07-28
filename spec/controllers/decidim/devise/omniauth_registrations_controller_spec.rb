# frozen_string_literal: true

require "spec_helper"

# Tests the controller as well as the underlying OmniAuth strategy. Note that
# this is why we are using the `:request` type instead of `:controller`, so
# that we get the OmniAuth middleware applied to the requests and the response
# to behave as it would behave in a normal situation.
describe Decidim::Devise::OmniauthRegistrationsController, type: :request do
  let(:organization) { create(:organization) }

  around do |example|
    # Silence the Omniauth logging during testing
    original_logger = OmniAuth.config.logger
    OmniAuth.config.logger = Logger.new(StringIO.new)

    host! organization.host

    example.run

    OmniAuth.config.logger = original_logger
  end

  describe "GET callback" do
    let(:callback_path) { "/users/auth/test/callback" }

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
