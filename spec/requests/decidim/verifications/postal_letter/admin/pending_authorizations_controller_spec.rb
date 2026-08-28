# frozen_string_literal: true

require "spec_helper"

describe Decidim::Verifications::PostalLetter::Admin::PendingAuthorizationsController do
  let(:workflow_name) { "postal_letter" }
  let(:url_helpers) { Decidim::Verifications::PostalLetter::AdminEngine.routes.url_helpers }

  it_behaves_like "audit authorization workflow admin controller list" do
    let(:target_path) { url_helpers.pending_authorizations_path }
    let(:audits_users) { true }
    let!(:authorizations) do
      users.each_with_index.map do |user, idx|
        create(
          :authorization,
          :pending,
          name: workflow_name,
          user:,
          verification_metadata: {
            verification_code: "12345#{idx}",
            letter_sent_at: 1.day.ago
          }
        )
      end
    end
  end
end
