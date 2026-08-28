# frozen_string_literal: true

require "spec_helper"

describe Decidim::Admin::LogsController do
  include_context "with auditable user read controller" do
    it_behaves_like "audit user read controller list" do
      let(:target_path) { url_helpers.logs_path }
      let(:queried_users) { logged_users }

      let(:logged_users) { create_list(:user, 30, :confirmed, :admin, organization:) }
      let!(:logs) do
        logged_users.map do |admin|
          create(:action_log, user: admin, organization:)
        end
      end
    end
  end
end
