# frozen_string_literal: true

require "spec_helper"

describe Decidim::Assemblies::Admin::AssemblyUserRolesController do
  include_context "with auditable user read controller" do
    let(:url_helpers) { Decidim::Assemblies::AdminEngine.routes.url_helpers }
    let(:assembly) { create(:assembly, organization:) }
    let!(:admins) { create_list(:user, 1, :confirmed, :admin, organization:) }

    it_behaves_like "audit user read controller list" do
      let(:moderators) { create_list(:assembly_moderator, 10, assembly:) }
      let(:collaborators) { create_list(:assembly_collaborator, 10, assembly:) }
      # 0.31 onwards: assembly_valuator -> assembly_evaluator
      let(:evaluators) { create_list(:assembly_valuator, 10, assembly:) }

      let!(:users) { moderators + collaborators + evaluators }
      let(:queried_users) { users }

      let(:target_path) { url_helpers.assembly_user_roles_path(assembly_slug: assembly.slug) }
    end

    it_behaves_like "audit user read controller single", :edit do
      let(:target_path) { url_helpers.edit_assembly_user_role_path(role, assembly_slug: assembly.slug) }
      let(:target_user) { create(:user, :confirmed, organization:) }

      let!(:role) { create(:assembly_user_role, assembly:, user: target_user, role: :moderator) }
    end
  end
end
