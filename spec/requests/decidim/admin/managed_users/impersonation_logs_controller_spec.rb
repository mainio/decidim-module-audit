# frozen_string_literal: true

require "spec_helper"

describe Decidim::Admin::ManagedUsers::ImpersonationLogsController do
  include_context "with auditable user read controller" do
    it_behaves_like "audit user read controller list" do
      let!(:impersonation_logs) { create_list(:impersonation_log, 10, admin: current_user, user: managed_user) }
      let(:managed_user) { create(:user, :managed, organization:) }

      let(:target_path) { url_helpers.impersonatable_user_impersonation_logs_path(managed_user) }
      let(:queried_users) { [current_user, managed_user] }
      let(:queried_amount_per_page) { 2 }
    end
  end
end
