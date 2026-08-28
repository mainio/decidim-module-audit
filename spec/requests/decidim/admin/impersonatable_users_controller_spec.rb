# frozen_string_literal: true

require "spec_helper"

describe Decidim::Admin::ImpersonatableUsersController do
  include_context "with auditable user read controller" do
    it_behaves_like "audit user read controller list" do
      let(:target_path) { url_helpers.impersonatable_users_path }
      let(:queried_users) { users }
      let(:queried_amount_per_page) { 15 }

      let!(:users) { create_list(:user, 20, :confirmed, organization:) }
    end
  end
end
