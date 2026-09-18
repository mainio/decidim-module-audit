# frozen_string_literal: true

require "spec_helper"

describe Decidim::UserActivitiesController do
  subject { get(target_path, params: { locale: I18n.default_locale }) }

  include_context "with auditable user read controller" do
    let(:url_helpers) { Decidim::Core::Engine.routes.url_helpers }

    it_behaves_like "audit user read controller single", :index do
      let(:target_path) { url_helpers.profile_activity_path(target_user.nickname) }
      let!(:target_user) { create(:user, :confirmed, organization:) }
      let(:audit_channel) { "users_public" }
    end
  end
end
