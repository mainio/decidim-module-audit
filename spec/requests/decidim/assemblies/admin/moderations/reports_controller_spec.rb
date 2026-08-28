# frozen_string_literal: true

require "spec_helper"

describe Decidim::Assemblies::Admin::Moderations::ReportsController do
  it_behaves_like "audit user read for moderation reports" do
    let(:url_helpers) { Decidim::Assemblies::AdminEngine.routes.url_helpers }
    let(:participatory_space) { create(:assembly, organization:) }

    let(:reports_path) { url_helpers.moderation_reports_path(assembly_slug: participatory_space.slug, moderation_id: moderation) }
  end
end
