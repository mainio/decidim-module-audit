# frozen_string_literal: true

require "spec_helper"

describe Decidim::Verifications::IdDocuments::Admin::OfflineConfirmationsController do
  let(:workflow_name) { "id_documents" }
  let(:url_helpers) { Decidim::Verifications::IdDocuments::AdminEngine.routes.url_helpers }

  it_behaves_like "audit authorization workflow admin controller action", :new do
    let(:target_path) { url_helpers.new_offline_confirmation_path }
  end
end
