# frozen_string_literal: true

require "spec_helper"

describe Decidim::User do
  let(:organization) { create(:organization) }

  it_behaves_like "auditable record" do
    let(:resource_type) { "Decidim::UserBaseEntity" }
    let(:create_attributes) do
      {
        name: "John Doe",
        nickname: "john_doe",
        email: "john.doe@example.org",
        password: "decidim123456789",
        organization:,
        confirmed_at: Time.current,
        locale: I18n.default_locale,
        accepted_tos_version: organization.tos_version + 1.hour,
        newsletter_notifications_at: Time.current,
        tos_agreement: true,
        password_updated_at: Time.current
      }
    end
    let(:expected_create_changes) do
      {
        "id" => [nil, an_instance_of(Integer)],
        "name" => [nil, create_attributes[:name]],
        "type" => [nil, "Decidim::User"],
        "email" => ["", create_attributes[:email]],
        "locale" => [nil, create_attributes[:locale].to_s],
        "nickname" => ["", create_attributes[:nickname]],
        "created_at" => [nil, an_instance_of(String)],
        "updated_at" => [nil, an_instance_of(String)],
        "confirmed_at" => [nil, create_attributes[:confirmed_at].iso8601(3)],
        "encrypted_password" => ["", an_instance_of(String)],
        "password_updated_at" => [nil, create_attributes[:password_updated_at].iso8601(3)],
        "accepted_tos_version" => [nil, create_attributes[:accepted_tos_version].iso8601(3)],
        "decidim_organization_id" => [nil, organization.id],
        "newsletter_notifications_at" => [nil, create_attributes[:newsletter_notifications_at].iso8601(3)]
      }
    end
    let(:existing_record) { create(:user, :confirmed, organization:) }
    let(:update_attributes) do
      {
        name: "John Doe",
        nickname: "john_doe"
      }
    end
    let(:expected_update_changes) do
      {
        "name" => [record_before_update.name, update_attributes[:name]],
        "nickname" => [record_before_update.nickname, update_attributes[:nickname]],
        "updated_at" => [record_before_update.updated_at.iso8601(3), an_instance_of(String)]
      }
    end
  end

  describe "#create!" do
    subject do
      described_class.create!(
        name: "John Doe",
        nickname: "john_doe",
        email: "john.doe@example.org",
        password: "decidim123456789",
        organization:,
        confirmed_at: Time.current,
        accepted_tos_version: organization.tos_version + 1.hour,
        tos_agreement: true
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
    subject { record.update!(password: "decidim123456", password_confirmation: "decidim123456") }

    let(:record) { create(:user, :confirmed, organization:) }

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
