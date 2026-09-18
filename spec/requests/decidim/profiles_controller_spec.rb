# frozen_string_literal: true

require "spec_helper"

describe Decidim::ProfilesController do
  subject { get(target_path, params: { locale: I18n.default_locale }) }

  include_context "with auditable user read controller" do
    let(:url_helpers) { Decidim::Core::Engine.routes.url_helpers }

    it_behaves_like "audit user read controller single", :show do
      let(:target_path) { url_helpers.profile_path(target_user.nickname) }
      let!(:target_user) { create(:user, :confirmed, organization:) }
      let(:audit_channel) { "users_public" }
    end

    it_behaves_like "audit user read controller single", :badges do
      let(:target_path) { url_helpers.profile_badges_path(target_user.nickname) }
      let!(:target_user) { create(:user, :confirmed, organization:) }
      let(:audit_channel) { "users_public" }
    end

    it_behaves_like "audit user read controller single", :tooltip do
      let(:target_path) { url_helpers.profile_tooltip_path(target_user.nickname) }
      let!(:target_user) { create(:user, :confirmed, organization:) }
      let(:audit_channel) { "users_public" }
    end

    it_behaves_like "audit user read controller list", :following do
      let!(:target_user) { create(:user, :confirmed, organization:) }
      let(:target_path) { url_helpers.profile_following_path(target_user.nickname) }
      let(:queried_amount_per_page) { 1 }
      let(:queried_users) { [target_user] }
      let(:audit_channel) { "users_public" }
    end

    context "with following users" do
      it_behaves_like "audit user read controller list", :following do
        let!(:followed) { create_list(:user, 30, :confirmed, organization:) }
        let!(:follows) { followed.map { |user| create(:follow, followable: user, user: target_user) } }
        let!(:target_user) { create(:user, :confirmed, organization:) }

        let(:target_path) { url_helpers.profile_following_path(target_user.nickname) }
        let(:queried_amount_per_page) { 21 } # 20 per page + the target user itself
        let(:queried_users) { [target_user] + followed }
        let(:audit_channel) { "users_public" }
      end
    end

    it_behaves_like "audit user read controller list", :followers do
      let!(:target_user) { create(:user, :confirmed, organization:) }
      let(:target_path) { url_helpers.profile_followers_path(target_user.nickname) }
      let(:queried_amount_per_page) { 1 }
      let(:queried_users) { [target_user] }
      let(:audit_channel) { "users_public" }
    end

    context "with followers" do
      it_behaves_like "audit user read controller list", :followers do
        let!(:followers) { create_list(:user, 30, :confirmed, organization:) }
        let!(:follows) { followers.map { |user| create(:follow, followable: target_user, user:) } }
        let!(:target_user) { create(:user, :confirmed, organization:) }

        let(:target_path) { url_helpers.profile_followers_path(target_user.nickname) }
        let(:queried_amount_per_page) { 21 } # 20 per page + the target user itself
        let(:queried_users) { [target_user] + followers }
        let(:audit_channel) { "users_public" }
      end
    end

    it_behaves_like "audit user read controller single", :groups do
      let(:target_path) { url_helpers.profile_groups_path(target_user.nickname) }
      let!(:target_user) { create(:user, :confirmed, organization:) }
      let(:audit_channel) { "users_public" }
    end

    it_behaves_like "audit user read controller list", :members do
      let!(:group_admins) { create_list(:user, 15, :confirmed, organization:) }
      let!(:group_members) { create_list(:user, 15, :confirmed, organization:) }
      let!(:memberships) do
        group_admins.map do |user|
          create(:user_group_membership, user:, user_group: target_group, role: :admin)
        end +
          group_members.map do |user|
            create(:user_group_membership, user:, user_group: target_group, role: :member)
          end
      end
      let(:target_group) { create(:user_group, :confirmed, users: [current_user], organization:) }

      let(:target_path) { url_helpers.profile_members_path(target_group.nickname) }
      let(:queried_amount_per_page) { 20 }
      let(:queried_users) { [current_user] + group_admins + group_members }
      let(:audit_channel) { "users_public" }
    end

    it_behaves_like "audit user read controller list", :group_members do
      let!(:group_members) { create_list(:user, 30, :confirmed, organization:) }
      let!(:memberships) do
        group_members.map do |user|
          create(:user_group_membership, user:, user_group: target_group, role: :member)
        end
      end
      let(:target_group) { create(:user_group, :confirmed, users: [current_user], organization:) }

      let(:target_path) { url_helpers.profile_group_members_path(target_group.nickname) }
      let(:queried_amount_per_page) { 20 }
      let(:queried_users) { group_members }
      let(:audit_channel) { "users_public" }
    end

    it_behaves_like "audit user read controller list", :group_admins do
      let!(:group_members) { create_list(:user, 30, :confirmed, organization:) }
      let!(:memberships) do
        group_members.map do |user|
          create(:user_group_membership, user:, user_group: target_group, role: :admin)
        end
      end
      let(:target_group) { create(:user_group, :confirmed, users: [current_user], organization:) }

      let(:target_path) { url_helpers.profile_group_admins_path(target_group.nickname) }
      let(:queried_amount_per_page) { 20 }
      let(:queried_users) { group_members }
      let(:audit_channel) { "users_public" }
    end
  end
end
