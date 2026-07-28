# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Log do
  let(:organization) { create(:organization) }
  let(:participatory_process) { create(:participatory_process, organization:) }
  let(:component) { create(:component, participatory_space: participatory_process) }
  let(:resource) { create(:dummy_resource, component:, author:) }
  let!(:author) { create(:user, :confirmed, organization:) }

  let(:valid_attributes) do
    {
      organization:,
      resource:,
      level: "info",
      channel: "testing",
      event: "test"
    }
  end

  describe "#create!" do
    subject { described_class.create!(attributes) }

    context "with valid attributes" do
      let(:attributes) { valid_attributes }

      it "creates a new record" do
        expect { subject }.to change(described_class, :count).by(1)
      end

      context "without organization" do
        let(:attributes) { valid_attributes.except(:organization) }

        it "creates a new record" do
          expect { subject }.to change(described_class, :count).by(1)
        end
      end
    end

    context "without level" do
      let(:attributes) { valid_attributes.except(:level) }

      it "creates a new record with the default level" do
        expect { subject }.to change(described_class, :count).by(1)

        expect(subject.level).to eq("info")
      end
    end

    context "without channel" do
      let(:attributes) { valid_attributes.except(:channel) }

      it "raises an error" do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "without event" do
      let(:attributes) { valid_attributes.except(:event) }

      it "raises an error" do
        expect { subject }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "#update!" do
    let(:log) { described_class.create!(valid_attributes) }

    it "raises an error after create" do
      expect { log.update!(channel: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "raises an error after find" do
      record = described_class.find(log.id)
      expect { record.update!(channel: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe "#actor_gid" do
    subject { log.actor_gid }

    let(:log) do
      described_class.create!(valid_attributes.merge(actor: actor.to_gid))
    end
    let(:actor) { create(:user, :confirmed, organization:) }

    it "returns the actor GID in text" do
      expect(subject).to eq(actor.to_gid.to_s)
    end
  end

  describe "#actor" do
    subject { log.actor }

    let(:log) do
      described_class.create!(valid_attributes.merge(actor: actor.to_gid))
    end
    let(:actor) { create(:user, :confirmed, organization:) }

    it "returns the actor object" do
      expect(subject).to eq(actor)
    end

    context "with visitor" do
      let(:actor) { Decidim::Audit::Actor::Visitor.new("S", SecureRandom.uuid, "1.2.3.4") }

      it "returns the actor object" do
        expect(subject).to be_a(Decidim::Audit::Actor::Visitor)
        expect(subject.type).to eq("S")
        expect(subject.identifier).to eq(actor.identifier)
        expect(subject.ip).to eq(actor.ip)
      end
    end
  end

  # Ensures that direct updates to the database are blocked by the protection
  # rule defined in the migration.
  describe ".update_all" do
    subject { described_class.where(id: log.id).update_all(channel: "changed") } # rubocop:disable Rails/SkipsModelValidations

    let(:log) { described_class.create!(valid_attributes) }

    it "does not allow updating records directly through the DB query" do
      expect { subject }.not_to change { log.reload.channel }.from(log.channel)
    end
  end
end
