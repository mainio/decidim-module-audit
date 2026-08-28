# frozen_string_literal: true

require "spec_helper"

describe Decidim::Admin::GlobalModerations::ReportsController do
  it_behaves_like "audit user read for moderation reports" do
    let(:participatory_space) { create(:participatory_process, organization:) }

    let(:reports_path) { url_helpers.moderation_reports_path(moderation_id: moderation) }
  end
end
