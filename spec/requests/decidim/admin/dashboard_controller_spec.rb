# frozen_string_literal: true

require "spec_helper"

describe Decidim::Admin::DashboardController do
  include_context "with auditable user read controller" do
    let!(:admins) { create_list(:user, 10, :confirmed, :admin, organization:) }

    it_behaves_like "audit user read controller list", :show do
      let!(:logs) do
        admins.map do |admin|
          create(:action_log, user: admin, organization:)
        end
      end

      let(:target_path) { url_helpers.root_path }
      let(:queried_amount_per_page) { 5 }
      let(:queried_users) { admins }
    end
  end
end
