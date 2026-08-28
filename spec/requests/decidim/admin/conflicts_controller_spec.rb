# frozen_string_literal: true

require "spec_helper"

describe Decidim::Admin::ConflictsController do
  include_context "with auditable user read controller" do
    it_behaves_like "audit user read controller list" do
      let(:target_path) { url_helpers.conflicts_path }
      let(:queried_users) { managed_users + current_users }

      let!(:conflicts) do
        current_users.each_with_index.map do |user, idx|
          create(:conflict, current_user: user, managed_user: managed_users[idx])
        end
      end
      let(:managed_users) { create_list(:user, 30, :managed, organization:) }
      let(:current_users) { create_list(:user, 30, :confirmed, organization:) }
      # For each conflict, both the current user and managed user is queried.
      let(:queried_amount_per_page) { Decidim::Paginable::OPTIONS.first * 2 }
    end

    it_behaves_like "audit user read controller single", :edit do
      let(:target_path) { url_helpers.edit_conflict_path(conflict) }
      let(:target_users) { [conflict_user, managed_user] }

      let!(:conflict) { create(:conflict, current_user: conflict_user, managed_user:) }
      let(:conflict_user) { create(:user, :confirmed, organization:) }
      let(:managed_user) { create(:user, :managed, organization:) }
    end
  end
end
