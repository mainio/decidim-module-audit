# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Auditable do
  let(:organization) { create(:organization) }
  let(:component) { create(:dummy_component, organization:) }
  let!(:author) { create(:user, :confirmed, organization:) }

  around do |example|
    mod = Decidim::Audit::Auditable
    klass = Class.new(Decidim::Dev::ApplicationRecord) do
      self.table_name = "decidim_dev_dummy_resources"

      include Decidim::HasComponent
      include Decidim::Authorable
      include Decidim::TranslatableResource
      include mod

      translatable_fields :title
    end
    described_class.const_set(:DummyResource, klass)

    example.run

    described_class.class_eval do
      remove_const(:DummyResource)
    end
  end

  it_behaves_like "auditable record" do
    let(:resource_class) { described_class::DummyResource }
    let(:create_attributes) do
      {
        title: Decidim::Faker::Localized.literal("Resource title"),
        component:,
        author:
      }
    end
    let(:expected_create_changes) do
      {
        "id" => [nil, an_instance_of(Integer)],
        "created_at" => [nil, an_instance_of(String)],
        "updated_at" => [nil, an_instance_of(String)],
        "decidim_author_id" => [nil, author.id],
        "decidim_author_type" => [nil, "Decidim::UserBaseEntity"],
        "decidim_component_id" => [nil, component.id],
        "title" => [nil, create_attributes[:title]]
      }
    end
    let(:existing_record) do
      resource_class.create!(
        create_attributes.merge(
          title: Decidim::Faker::Localized.literal("Original title")
        )
      )
    end
    let(:update_attributes) do
      {
        title: Decidim::Faker::Localized.literal("Resource title")
      }
    end
    let(:expected_update_changes) do
      {
        "updated_at" => [an_instance_of(String), an_instance_of(String)],
        "title" => [record_before_update.title, update_attributes[:title]]
      }
    end
  end

  context "when specific attributes are excluded" do
    before do
      described_class::DummyResource.exclude_auditable_attributes! :title, :decidim_author_id, :decidim_author_type, :decidim_component_id
    end

    it_behaves_like "auditable record" do
      let(:resource_class) { described_class::DummyResource }
      let(:create_attributes) do
        {
          title: Decidim::Faker::Localized.literal("Resource title"),
          component:,
          author:
        }
      end
      let(:expected_create_changes) do
        {
          "id" => [nil, an_instance_of(Integer)],
          "created_at" => [nil, an_instance_of(String)],
          "updated_at" => [nil, an_instance_of(String)]
        }
      end
      let(:existing_record) do
        resource_class.create!(
          create_attributes.merge(
            title: Decidim::Faker::Localized.literal("Original title")
          )
        )
      end
      let(:update_attributes) do
        {
          title: Decidim::Faker::Localized.literal("Resource title")
        }
      end
      let(:expected_update_changes) do
        {
          "updated_at" => [an_instance_of(String), an_instance_of(String)]
        }
      end
      let(:expected_destroy_changes) do
        existing_record.attributes.except("title", "decidim_author_id", "decidim_author_type", "decidim_component_id").transform_values do |value|
          value = value.iso8601(3) if value.is_a?(ActiveSupport::TimeWithZone)

          [value, nil]
        end
      end
    end
  end

  describe ".audit_read" do
    let(:resource_class) { described_class::DummyResource }
    let(:resource_attributes) do
      {
        title: Decidim::Faker::Localized.literal("Resource title"),
        component:
      }
    end
    let!(:author2) { create(:user, :confirmed, organization:) }
    let!(:existing_by_author1) do
      3.times.map { resource_class.create!(resource_attributes.merge(author:)) }
    end
    let!(:existing_by_author2) do
      2.times.map { resource_class.create!(resource_attributes.merge(author: author2)) }
    end

    context "when no auditable records are fetched" do
      it "does not add an audit log record" do
        expect do
          Decidim::User.audit_read(:read) do
            resource_class.find(existing_by_author1[0].id)
            resource_class.find(existing_by_author1[1].id)
            resource_class.where(author:).to_a
          end
        end.not_to change(Decidim::Audit::Log, :count)
      end
    end

    context "when multiple audit blocks are present" do
      it "maps the audited records to the correct flags" do
        expect do
          resource_class.audit_read(:read) do
            resource_class.find(existing_by_author1[0].id)
            resource_class.audit_read(:other) do
              resource_class.find(existing_by_author2[0].id)
            end
          end
        end.to change(Decidim::Audit::Log, :count).by(2)

        logs = Decidim::Audit::Log.where(channel: resource_class.table_name).last(2)
        expect(logs[0].event).to eq("other")
        expect(logs[0].resource).to be_nil
        expect(logs[0].details).to eq("ids" => [existing_by_author2[0].id])
        expect(logs[1].event).to eq("read")
        expect(logs[1].resource).to eq(existing_by_author1[0])
        expect(logs[1].details).to be_nil
      end
    end

    context "with #find" do
      it "audits a single find" do
        expect do
          resource_class.audit_read(:read) do
            resource_class.find(existing_by_author1[0].id)
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: resource_class.table_name).last
        expect(log.event).to eq("read")
        expect(log.level).to eq("info")
        expect(log.resource).to eq(existing_by_author1[0])
      end

      it "audits a single list find" do
        expect do
          resource_class.audit_read(:read_list) do
            resource_class.find(existing_by_author1[0].id)
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: resource_class.table_name).last
        expect(log.event).to eq("read_list")
        expect(log.level).to eq("info")
        expect(log.resource).to be_nil
        expect(log.details).to eq("ids" => [existing_by_author1[0].id])
      end

      it "audits all finds" do
        expect do
          resource_class.audit_read(:read) do
            resource_class.find(existing_by_author1[0].id)
            resource_class.find(existing_by_author1[1].id)
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: resource_class.table_name).last
        expect(log.event).to eq("read")
        expect(log.level).to eq("info")
        expect(log.resource).to be_nil
        expect(log.details).to eq("ids" => existing_by_author1[0..1].map(&:id))
      end

      it "does not record fetches for the same record multiple times" do
        expect do
          resource_class.audit_read(:read) do
            resource_class.find(existing_by_author1[0].id)
            resource_class.find(existing_by_author1[0].id)
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: resource_class.table_name).last
        expect(log.event).to eq("read")
        expect(log.level).to eq("info")
        expect(log.resource).to eq(existing_by_author1[0])
      end
    end

    context "with #find_by" do
      it "audits a single find" do
        expect do
          resource_class.audit_read(:read) do
            resource_class.order(:id).find_by(author:)
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: resource_class.table_name).last
        expect(log.event).to eq("read")
        expect(log.level).to eq("info")
        expect(log.resource).to eq(existing_by_author1[0])
      end

      it "audits a single list find" do
        expect do
          resource_class.audit_read(:read_list) do
            resource_class.order(:id).find_by(author:)
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: resource_class.table_name).last
        expect(log.event).to eq("read_list")
        expect(log.level).to eq("info")
        expect(log.resource).to be_nil
        expect(log.details).to eq("ids" => [existing_by_author1[0].id])
      end

      it "audits all returned records" do
        expect do
          resource_class.audit_read(:read) do
            resource_class.order(:id).find_by(author:)
            resource_class.order(:id).offset(1).find_by(author:)
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: resource_class.table_name).last
        expect(log.event).to eq("read")
        expect(log.level).to eq("info")
        expect(log.resource).to be_nil
        expect(log.details).to eq("ids" => existing_by_author1[0..1].map(&:id))
      end
    end

    context "with #where" do
      it "audits all returned records" do
        expect do
          resource_class.audit_read(:read_list) do
            resource_class.order(:id).where(author:).to_a
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: resource_class.table_name).last
        expect(log.event).to eq("read_list")
        expect(log.level).to eq("info")
        expect(log.resource).to be_nil
        expect(log.details).to eq("ids" => existing_by_author1.map(&:id))
      end
    end

    context "with has_many association" do
      let!(:organization_users) { create_list(:user, 5, :confirmed, organization:) }
      let!(:other_users) { create_list(:user, 3, :confirmed) }

      it "audits all returned records" do
        expect do
          Decidim::User.audit_read(:read_list) do
            organization.users.order(:id).to_a
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: Decidim::User.table_name).last
        expect(log.event).to eq("read_list")
        expect(log.level).to eq("info")
        expect(log.resource).to be_nil
        expect(log.details).to eq("ids" => [author.id, author2.id] + organization_users.map(&:id))
      end
    end

    context "with belongs_to association" do
      it "audits a single find" do
        expect do
          Decidim::User.audit_read(:read) do
            resource = resource_class.find_by(author:)
            resource.author
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: Decidim::User.table_name).last
        expect(log.event).to eq("read")
        expect(log.level).to eq("info")
        expect(log.resource).to eq(author)
      end

      it "audits all finds" do
        expect do
          Decidim::User.audit_read(:read) do
            resource = resource_class.find_by(author:)
            resource.author
            resource = resource_class.find_by(author: author2)
            resource.author
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: Decidim::User.table_name).last
        expect(log.event).to eq("read")
        expect(log.level).to eq("info")
        expect(log.resource).to be_nil
        expect(log.details).to eq("ids" => [author.id, author2.id])
      end
    end

    context "with .includes query batch" do
      it "audits a single find" do
        expect do
          Decidim::User.audit_read(:read) do
            resource_class.includes(:author).find_by(author:)
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: Decidim::User.table_name).last
        expect(log.event).to eq("read")
        expect(log.level).to eq("info")
        expect(log.resource).to eq(author)
      end

      it "audits all finds" do
        expect do
          Decidim::User.audit_read(:read) do
            resource_class.includes(:author).where(author: [author, author2]).to_a
          end
        end.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.where(channel: Decidim::User.table_name).last
        expect(log.event).to eq("read")
        expect(log.level).to eq("info")
        expect(log.resource).to be_nil
        expect(log.details).to match("ids" => an_instance_of(Array))
        expect(log.details["ids"]).to contain_exactly(author.id, author2.id)
      end
    end
  end

  describe ".audit_read_multiple" do
    let!(:user) { create(:user, :confirmed, organization:) }
    let!(:authorization) { create(:authorization, user:) }

    it "audits the read for multiple records" do
      expect do
        described_class.audit_read_multiple(
          :read,
          Decidim::User,
          Decidim::Authorization
        ) do
          Decidim::User.find(user.id)
          Decidim::Authorization.find(authorization.id)
        end
      end.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      expect(logs[0].channel).to eq("decidim_users")
      expect(logs[0].resource).to eq(user)
      expect(logs[1].channel).to eq("decidim_authorizations")
      expect(logs[1].resource).to eq(authorization)
      logs.each do |log|
        expect(log.event).to eq("read")
        expect(log.level).to eq("info")
        expect(log.details).to be_nil
      end
    end
  end

  describe described_class::RecordStore do
    subject(:instance) { described_class.new }

    let(:resource_class) { described_class::DummyResource }

    after do
      described_class.remove_instance_variable(:@stores) if described_class.instance_variable_defined?(:@stores)
    end

    describe ".for" do
      context "without audit flag" do
        subject { described_class.for(resource_class) }

        it { is_expected.to be_nil }
      end

      context "with audit flag" do
        subject { described_class.for(resource_class, :read) }

        it { is_expected.to be_a(described_class) }

        it "returns a dedicated instance for different flags" do
          expect(subject).not_to eq(described_class.for(resource_class, :other))
        end
      end
    end

    describe ".clear" do
      subject { described_class.clear(resource_class, :read) }

      context "when stores are not initialized" do
        it { is_expected.to be(false) }
      end

      context "when stores are not initialized for the target class" do
        before { described_class.for(Decidim::Audit::Auditable, :read) }

        it { is_expected.to be(false) }
      end

      context "when a store is initialized for the target class" do
        before { described_class.for(resource_class, :read) }

        it { is_expected.to be(true) }

        it "clears the stores" do
          subject
          expect(described_class.instance_variable_defined?(:@stores)).to be(false)
        end

        context "and there is another store defined for the class" do
          it "does not clear the other store" do
            other_store = described_class.for(resource_class, :other)
            subject
            expect(described_class.for(resource_class, :other)).to eq(other_store)
          end
        end

        context "and there is another store defined for other class" do
          it "does not clear the other store" do
            other_store = described_class.for(Decidim::Audit::Auditable, :read)
            subject
            expect(described_class.for(Decidim::Audit::Auditable, :read)).to eq(other_store)
          end
        end
      end
    end

    describe "#initialize" do
      it "initializes an empty data array" do
        expect(subject.get).to eq([])
      end
    end

    describe "#add" do
      context "when adding a single item" do
        subject { instance.add(123) }

        before { subject }

        it "adds the item to the data array" do
          expect(instance.get).to contain_exactly(123)
        end
      end

      context "when adding multiple items" do
        subject { instance.add(123, 456, 789) }

        before { subject }

        it "adds the items to the data array" do
          expect(instance.get).to contain_exactly(123, 456, 789)
        end
      end
    end

    describe "#get" do
      subject { instance.get }

      context "when empty" do
        it { is_expected.to eq([]) }
      end

      context "when containing items" do
        before { instance.add(123, 456, 789) }

        it { is_expected.to contain_exactly(123, 456, 789) }
      end
    end

    describe "#clear" do
      subject { instance.clear }

      before { instance.add(123, 456, 789) }

      it "clears the data array" do
        subject
        expect(instance.get).to eq([])
      end
    end
  end
end
