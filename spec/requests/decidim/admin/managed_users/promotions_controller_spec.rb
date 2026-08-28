# frozen_string_literal: true

require "spec_helper"

describe Decidim::Admin::ManagedUsers::PromotionsController do
  include_context "with auditable user read controller" do
    it_behaves_like "audit user read controller single", :new do
      let(:target_path) { url_helpers.new_impersonatable_user_promotion_path(target_user) }
      let!(:target_user) { create(:user, :managed, organization:) }
    end
  end
end
