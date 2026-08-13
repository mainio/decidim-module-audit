# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Resolver::UserRoles do
  subject(:instance) { described_class.new(user) }

  describe "#resolve" do
    subject { instance.resolve }

    context "without roles" do
      let(:user) { build(:user, :confirmed) }

      it { is_expected.to be_nil }
    end

    context "with account roles" do
      let(:user) { build(:user, :confirmed, :user_manager) }

      it { is_expected.to eq(["user_manager"]) }
    end

    context "with participatory space roles" do
      let(:organization) { create(:organization) }
      let(:user) { create(:user, :confirmed, organization:) }

      # Just to ensure only the correct roles are returned
      let(:second_user) { create(:user, :confirmed, organization:) }
      let(:second_user_space1) { create(:assembly, :published, organization:) }
      let(:second_user_space2) { create(:assembly, :published, organization:) }
      let!(:second_user_role1) { create(:assembly_user_role, assembly: second_user_space1, user: second_user, role: "admin") }
      let!(:second_user_role2) { create(:assembly_user_role, assembly: second_user_space2, user: second_user, role: "moderator") }
      let!(:third_user) do
        create(:user, :confirmed, organization:).tap do |usr|
          # Skip the validations because "custom_role" is not available by default.
          usr.roles = ["custom_role"]
          usr.save!(validate: false)
        end
      end

      context "with assembly roles" do
        let(:space1) { create(:assembly, :published, organization:) }
        let(:space2) { create(:assembly, :published, organization:) }
        let!(:role1) { create(:assembly_user_role, assembly: space1, user:, role: "collaborator") }
        let!(:role2) { create(:assembly_user_role, assembly: space2, user:, role: "moderator") }

        it { is_expected.to eq(["assembly_#{space1.id}_collaborator", "assembly_#{space2.id}_moderator"]) }
      end

      context "with participatory process roles" do
        let(:space1) { create(:participatory_process, :published, organization:) }
        let(:space2) { create(:participatory_process, :published, organization:) }
        let!(:role1) { create(:participatory_process_user_role, participatory_process: space1, user:, role: "collaborator") }
        let!(:role2) { create(:participatory_process_user_role, participatory_process: space2, user:, role: "moderator") }

        it { is_expected.to eq(["process_#{space1.id}_collaborator", "process_#{space2.id}_moderator"]) }
      end

      context "with account roles and participatory space roles" do
        let(:user) { create(:user, :confirmed, :user_manager, organization:) }
        let(:space1) { create(:assembly, :published, organization:) }
        let(:space2) { create(:participatory_process, :published, organization:) }
        let!(:role1) { create(:assembly_user_role, assembly: space1, user:, role: "collaborator") }
        let!(:role2) { create(:participatory_process_user_role, participatory_process: space2, user:, role: "moderator") }

        it { is_expected.to eq(["user_manager", "assembly_#{space1.id}_collaborator", "process_#{space2.id}_moderator"]) }
      end
    end
  end

  describe ".for" do
    subject { described_class.for(actor) }

    context "with organization user" do
      let(:actor) { build(:user, :confirmed, :user_manager) }

      it { is_expected.to eq(["user_manager"]) }
    end

    context "with system admin" do
      let(:actor) { build(:admin) }

      it { is_expected.to be_nil }
    end
  end
end
