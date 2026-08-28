# frozen_string_literal: true

require "spec_helper"

describe Decidim::Admin::OfficializationsController do
  include_context "with auditable user read controller" do
    it_behaves_like "audit user read controller list" do
      let(:target_path) { url_helpers.officializations_path }
      let(:queried_users) { users + admins }

      let!(:users) { create_list(:user, 20, :confirmed, organization:) }
      let!(:admins) { create_list(:user, 20, :confirmed, :admin, organization:) }
    end

    it_behaves_like "audit user read controller single", :show_email do
      let(:target_path) { url_helpers.show_email_officialization_path(target_user) }
      let(:target_user) { create(:user, :confirmed, :admin, organization:) }
    end
  end
end
