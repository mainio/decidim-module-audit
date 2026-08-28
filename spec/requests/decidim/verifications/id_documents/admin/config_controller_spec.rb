# frozen_string_literal: true

require "spec_helper"

describe Decidim::Verifications::IdDocuments::Admin::ConfigController do
  let(:workflow_name) { "id_documents" }
  let(:url_helpers) { Decidim::Verifications::IdDocuments::AdminEngine.routes.url_helpers }

  it_behaves_like "audit authorization workflow admin controller action", :edit do
    let(:target_path) { url_helpers.edit_config_path }
  end
end
