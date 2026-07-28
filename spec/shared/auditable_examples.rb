# frozen_string_literal: true

shared_examples "auditable record" do
  let(:resource_class) { described_class }
  let(:resource_type) { resource_class.name }
  let(:expected_destroy_changes) do
    existing_record.attributes.transform_values do |value|
      value = value.iso8601(3) if value.is_a?(ActiveSupport::TimeWithZone)

      [value, nil]
    end
  end

  describe "#create!" do
    subject { resource_class.create!(create_attributes) }

    it "logs the record changes on create" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.last
      expect(log.level).to eq("info")
      expect(log.channel).to eq(resource_class.table_name)
      expect(log.event).to eq("create")
      expect(log.resource_type).to eq(resource_type)
      expect(log.resource_changes).to match(expected_create_changes)
    end
  end

  describe "update!" do
    subject { existing_record.update!(update_attributes) }

    let!(:record_before_update) { resource_class.find(existing_record.id) }

    it "logs the record changes on create" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.last
      expect(log.level).to eq("info")
      expect(log.channel).to eq(resource_class.table_name)
      expect(log.event).to eq("update")
      expect(log.resource_type).to eq(resource_type)
      expect(log.resource_changes).to match(expected_update_changes)
    end
  end

  describe "destroy!" do
    subject { existing_record.destroy! }

    # Ensure the record exists before the spec.
    before { existing_record }

    it "logs the record changes on destroy" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.last
      expect(log.level).to eq("info")
      expect(log.channel).to eq(resource_class.table_name)
      expect(log.event).to eq("destroy")
      expect(log.resource_type).to eq(resource_type)
      expect(log.resource_changes).to match(expected_destroy_changes)
    end
  end
end
