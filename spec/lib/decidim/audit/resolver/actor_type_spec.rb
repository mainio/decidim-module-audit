# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Resolver::ActorType do
  subject(:instance) { described_class.new(actor) }

  describe "#resolve" do
    subject { instance.resolve }

    context "with nil" do
      let(:actor) { nil }

      it { is_expected.to be_nil }
    end

    context "with system admin" do
      let(:actor) { build(:admin) }

      it { is_expected.to eq("app_admin") }
    end

    context "with organization admin" do
      let(:actor) { build(:user, :admin, :confirmed) }

      it { is_expected.to eq("organization_admin") }
    end

    context "with organization user" do
      let(:actor) { build(:user, :confirmed) }

      it { is_expected.to eq("organization_user") }
    end

    context "with organization API user" do
      # let(:actor) { build(:api_user) }

      # it { is_expected.to eq("organization_api_user") }

      it "waits for 0.31 update" do
        # Just to ensure a failure after the 0.31 update. The correct test is
        # above.
        expect(Decidim.version).to be < Gem::Version.new("0.31.0"), "Please complete the ApiUser specs after the update."
      end
    end

    context "with system user" do
      let(:actor) { build(:audit_system_user) }

      it { is_expected.to eq("system_user") }
    end

    context "with visitor" do
      let(:actor) { build(:audit_visitor) }

      it { is_expected.to eq("visitor") }
    end
  end
end
