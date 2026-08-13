# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Resolver::ActorDetails do
  subject(:instance) { described_class.new(actor) }

  describe ".for" do
    subject { described_class.for(actor) }

    context "with nil" do
      let(:actor) { nil }

      it "returns the correct details" do
        expect(subject.type).to be_nil
        expect(subject.roles).to be_nil
      end
    end

    context "with system admin" do
      let(:actor) { build(:admin) }

      it "returns the correct details" do
        expect(subject.type).to eq("app_admin")
        expect(subject.roles).to be_nil
      end
    end

    context "with organization admin" do
      let(:actor) { build(:user, :confirmed, :admin) }

      it "returns the correct details" do
        expect(subject.type).to eq("organization_admin")
        expect(subject.roles).to be_nil
      end
    end

    context "with organization user" do
      let(:actor) { build(:user, :confirmed) }

      it "returns the correct details" do
        expect(subject.type).to eq("organization_user")
        expect(subject.roles).to be_nil
      end

      context "with roles" do
        let(:organization) { create(:organization) }
        let(:actor) { create(:user, :confirmed, :user_manager, organization:) }
        let(:space1) { create(:assembly, :published, organization:) }
        let(:space2) { create(:participatory_process, :published, organization:) }
        let!(:role1) { create(:assembly_user_role, assembly: space1, user: actor, role: "collaborator") }
        let!(:role2) { create(:participatory_process_user_role, participatory_process: space2, user: actor, role: "moderator") }

        it "returns the correct details" do
          expect(subject.type).to eq("organization_user")
          expect(subject.roles).to eq(["user_manager", "assembly_#{space1.id}_collaborator", "process_#{space2.id}_moderator"])
        end
      end
    end

    context "with system user" do
      let(:actor) { build(:audit_system_user) }

      it "returns the correct details" do
        expect(subject.type).to eq("system_user")
        expect(subject.roles).to be_nil
      end
    end

    context "with visitor" do
      let(:actor) { build(:audit_visitor) }

      it "returns the correct details" do
        expect(subject.type).to eq("visitor")
        expect(subject.roles).to be_nil
      end
    end
  end
end
