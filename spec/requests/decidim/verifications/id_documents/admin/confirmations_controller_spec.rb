# frozen_string_literal: true

require "spec_helper"

describe Decidim::Verifications::IdDocuments::Admin::ConfirmationsController do
  let(:workflow_name) { "id_documents" }
  let(:url_helpers) { Decidim::Verifications::IdDocuments::AdminEngine.routes.url_helpers }

  it_behaves_like "audit authorization workflow admin controller action and authorization", :new do
    let(:target_path) { url_helpers.new_pending_authorization_confirmation_path(authorization.id) }

    let(:user) { create(:user, :confirmed, organization:) }
    let!(:authorization) do
      create(
        :authorization,
        :pending,
        name: workflow_name,
        user:,
        verification_metadata: {
          "verification_type" => "online",
          "document_type" => "identification_number",
          "document_number" => "XXXXXXXX"
        },
        verification_attachment: Decidim::Dev.test_file("id.jpg", "image/jpeg")
      )
    end
  end
end
