# frozen_string_literal: true

require "spec_helper"

describe Decidim::ParticipatoryProcesses::Admin::ParticipatoryProcessUserRolesController do
  include_context "with auditable user read controller" do
    let(:url_helpers) { Decidim::ParticipatoryProcesses::AdminEngine.routes.url_helpers }
    let(:participatory_process) { create(:participatory_process, organization:) }
    let!(:admins) { create_list(:user, 1, :confirmed, :admin, organization:) }

    it_behaves_like "audit user read controller list" do
      let(:moderators) { create_list(:process_moderator, 10, participatory_process:) }
      let(:collaborators) { create_list(:process_collaborator, 10, participatory_process:) }
      # 0.31 onwards: process_valuator -> process_evaluator
      let(:evaluators) { create_list(:process_valuator, 10, participatory_process:) }

      let!(:users) { moderators + collaborators + evaluators }
      let(:queried_users) { users }

      let(:target_path) { url_helpers.participatory_process_user_roles_path(participatory_process_slug: participatory_process.slug) }
    end

    it_behaves_like "audit user read controller single", :edit do
      let(:target_path) { url_helpers.edit_participatory_process_user_role_path(role, participatory_process_slug: participatory_process.slug) }
      let(:target_user) { create(:user, :confirmed, organization:) }

      let!(:role) { create(:participatory_process_user_role, participatory_process:, user: target_user, role: :moderator) }
    end
  end
end
