# frozen_string_literal: true

require "spec_helper"

describe Decidim::Devise::SessionsController do
  routes { Decidim::Core::Engine.routes }

  include Decidim::Core::Engine.routes.url_helpers

  let(:organization) { create(:organization) }

  before do
    request.env["decidim.current_organization"] = organization
    request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe "POST create" do
    let!(:user) { create(:user, :confirmed, organization:, password:) }
    let(:password) { "decidim123456789" }

    let(:provided_password) { password }
    let(:params) { { user: { email: user.email, password: provided_password } } }
    let(:request_params) { params.merge(locale: I18n.default_locale) }

    context "with correct credentials" do
      it "logs the login attempt and success" do
        expect { post(:create, params: request_params) }.to change(Decidim::Audit::Log, :count).by(3)

        expect(Decidim::Audit::Log.where(channel: "authentication", event: "attempt").count).to eq(1)
        expect(Decidim::Audit::Log.where(channel: "authentication", event: "success").count).to eq(1)
        expect(Decidim::Audit::Log.where(channel: "decidim_users", event: "update").count).to eq(1)
      end
    end

    context "with incorrect credentials" do
      let(:provided_password) { "incorrect" }

      it "logs the login attempt and failure" do
        expect { post(:create, params: request_params) }.to change(Decidim::Audit::Log, :count).by(2)

        expect(Decidim::Audit::Log.where(channel: "authentication", event: "attempt").count).to eq(1)
        expect(Decidim::Audit::Log.where(channel: "authentication", event: "failure").count).to eq(1)
      end
    end
  end
end
