# frozen_string_literal: true

require "spec_helper"

describe Decidim::System::Admin do
  it_behaves_like "auditable record" do
    let(:resource_type) { "Decidim::System::Admin" }
    let(:create_attributes) do
      {
        email: "system.admin@example.org",
        password: "decidim123456789"
      }
    end
    let(:expected_create_changes) do
      {
        "id" => [nil, an_instance_of(Integer)],
        "email" => ["", create_attributes[:email]],
        "created_at" => [nil, an_instance_of(String)],
        "updated_at" => [nil, an_instance_of(String)],
        "encrypted_password" => ["", an_instance_of(String)]
      }
    end
    let(:existing_record) { create(:admin) }
    let(:update_attributes) { { email: "updated.admin@example.org" } }
    let(:expected_update_changes) do
      {
        "email" => [record_before_update.email, update_attributes[:email]],
        "updated_at" => [record_before_update.updated_at.iso8601(3), an_instance_of(String)]
      }
    end
  end

  describe "#create!" do
    subject do
      described_class.create!(
        email: "system.admin@example.org",
        password: "decidim123456789"
      )
    end

    it "does not store the plain password" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.last
      expect(log.resource_changes.keys).not_to include("password")
      expect(log.resource_changes.keys).to include("encrypted_password")
    end
  end

  describe "#update!" do
    subject { record.update!(password: "decidim0123456789", password_confirmation: "decidim0123456789") }

    let(:record) { create(:admin) }

    it "does not store the plain password" do
      expect { subject }
        .to change(Decidim::Audit::Log, :count).by(1)
        .and change(record, :encrypted_password)

      log = Decidim::Audit::Log.last
      expect(log.resource_changes.keys).not_to include("password")
      expect(log.resource_changes.keys).to include("encrypted_password")
    end
  end
end
