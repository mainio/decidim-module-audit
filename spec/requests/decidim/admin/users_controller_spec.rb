# frozen_string_literal: true

require "spec_helper"

describe Decidim::Admin::UsersController do
  include_context "with auditable user read controller" do
    let!(:users) { create_list(:user, 5, :confirmed, organization:) }
    let!(:admins) { create_list(:user, 30, :admin, :confirmed, organization:) }

    it_behaves_like "audit user read controller list" do
      let(:target_path) { url_helpers.users_path }
      let(:queried_users) { admins }
    end
  end
end
