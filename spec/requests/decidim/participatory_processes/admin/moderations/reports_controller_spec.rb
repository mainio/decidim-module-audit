# frozen_string_literal: true

require "spec_helper"

describe Decidim::ParticipatoryProcesses::Admin::Moderations::ReportsController do
  it_behaves_like "audit user read for moderation reports" do
    let(:url_helpers) { Decidim::ParticipatoryProcesses::AdminEngine.routes.url_helpers }
    let(:participatory_space) { create(:participatory_process, organization:) }

    let(:reports_path) { url_helpers.moderation_reports_path(participatory_process_slug: participatory_space.slug, moderation_id: moderation) }
  end
end
