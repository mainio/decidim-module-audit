# frozen_string_literal: true

require "spec_helper"

describe Decidim::Authorization do
  let(:organization) { create(:organization) }
  let!(:user) { create(:user, :confirmed, organization:) }

  it_behaves_like "auditable record" do
    let(:resource_type) { "Decidim::Authorization" }
    let(:create_attributes) do
      {
        name: "dummy_authorization",
        user:,
        metadata: { foo: "bar" },
        granted_at: 1.day.ago
      }
    end
    let(:expected_create_changes) do
      {
        "id" => [nil, an_instance_of(Integer)],
        "created_at" => [nil, an_instance_of(String)],
        "updated_at" => [nil, an_instance_of(String)],
        "granted_at" => [nil, create_attributes[:granted_at].iso8601(3)],
        "name" => [nil, create_attributes[:name]],
        "decidim_user_id" => [nil, user.id]
      }
    end
    let(:existing_record) { create(:authorization, :granted, user:) }
    let(:update_attributes) do
      {
        metadata: { foo: "bar" }
      }
    end
    let(:expected_update_changes) do
      {
        "updated_at" => [record_before_update.updated_at.iso8601(3), an_instance_of(String)]
      }
    end
    let(:expected_destroy_changes) do
      existing_record.attributes.except("metadata", "verification_metadata").transform_values do |value|
        value = value.iso8601(3) if value.is_a?(ActiveSupport::TimeWithZone)

        [value, nil]
      end
    end
  end

  context "when not granted" do
    it_behaves_like "auditable record" do
      let(:resource_type) { "Decidim::Authorization" }
      let(:create_attributes) do
        {
          name: "dummy_authorization",
          user:,
          verification_metadata: { foo: "bar" }
        }
      end
      let(:expected_create_changes) do
        {
          "id" => [nil, an_instance_of(Integer)],
          "created_at" => [nil, an_instance_of(String)],
          "updated_at" => [nil, an_instance_of(String)],
          "name" => [nil, create_attributes[:name]],
          "decidim_user_id" => [nil, user.id]
        }
      end
      let(:existing_record) { create(:authorization, :pending, user:) }
      let(:update_attributes) do
        {
          verification_metadata: { foo: "bar" }
        }
      end
      let(:expected_update_changes) do
        {
          "updated_at" => [record_before_update.updated_at.iso8601(3), an_instance_of(String)]
        }
      end
      let(:expected_destroy_changes) do
        existing_record.attributes.except("metadata", "verification_metadata").transform_values do |value|
          value = value.iso8601(3) if value.is_a?(ActiveSupport::TimeWithZone)

          [value, nil]
        end
      end
    end
  end
end
