# frozen_string_literal: true

require "spec_helper"

describe Decidim::Verifications::CsvCensus::Admin::CensusController do
  let(:workflow_name) { "csv_census" }
  let(:url_helpers) { Decidim::Verifications::CsvCensus::AdminEngine.routes.url_helpers }

  # Uncomment after 0.31 update
  # it_behaves_like "audit authorization workflow admin controller list" do
  #   let(:target_path) { url_helpers.census_logs_path }
  #   let(:audits_users) { true }
  #   let(:audit_authorizations) { false }
  #   let(:users) { create_list(:user, 30, :confirmed, organization:) }
  #   let!(:datums) { users.map { |u| create(:csv_datum, email: u.email, organization:) } }
  # end

  describe "#index" do
    it "waits for 0.31 update" do
      # Just to ensure a failure after the 0.31 update. The correct test is above.
      expect(Decidim.version).to be < Gem::Version.new("0.31.0"), "Please complete the #{described_class} specs after the update."
    end
  end
end
