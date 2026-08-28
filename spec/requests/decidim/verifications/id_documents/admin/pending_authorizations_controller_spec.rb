# frozen_string_literal: true

require "spec_helper"

describe Decidim::Verifications::IdDocuments::Admin::PendingAuthorizationsController do
  let(:workflow_name) { "id_documents" }
  let(:url_helpers) { Decidim::Verifications::IdDocuments::AdminEngine.routes.url_helpers }

  it_behaves_like "audit authorization workflow admin controller list" do
    let(:target_path) { url_helpers.pending_authorizations_path }
    let!(:authorizations) do
      users.each_with_index.map do |user, idx|
        create(
          :authorization,
          :pending,
          name: workflow_name,
          user:,
          verification_metadata: {
            "verification_type" => "online",
            "document_type" => "identification_number",
            "document_number" => "#{idx}XXXXXXX"
          },
          verification_attachment: Decidim::Dev.test_file("id.jpg", "image/jpeg")
        )
      end
    end
  end
end
