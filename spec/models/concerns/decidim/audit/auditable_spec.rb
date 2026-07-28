# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Auditable do
  let(:organization) { create(:organization) }
  let(:component) { create(:dummy_component, organization:) }
  let!(:author) { create(:user, :confirmed, organization:) }

  before do
    mod = described_class
    klass = Class.new(Decidim::Dev::ApplicationRecord) do
      self.table_name = "decidim_dev_dummy_resources"

      include Decidim::HasComponent
      include Decidim::Authorable
      include Decidim::TranslatableResource
      include mod

      translatable_fields :title

      def name
        "#{mod}::DummyResource"
      end
    end
    described_class.const_set(:DummyResource, klass)
  end

  after do
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
end
