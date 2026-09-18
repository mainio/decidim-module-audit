# frozen_string_literal: true

require "spec_helper"

describe Decidim::DownloadYourDataController do
  let(:url_helpers) { Decidim::Core::Engine.routes.url_helpers }
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user, :confirmed, organization:) }

  before do
    host! organization.host
    login_as current_user, scope: :user

    # Ensures that authentication events are not logged during the actual test
    # request.
    get("/", params: { locale: I18n.default_locale })
  end

  shared_examples "audited action" do |action_name|
    let(:target_path) { url_helpers.public_send(:"#{action_name}_download_your_data_path") }

    describe "##{action_name}" do
      it "logs the action" do
        expect { subject }.to change(Decidim::Audit::Log, :count).by(1)

        log = Decidim::Audit::Log.order(:id).last
        details = [:level, :channel, :event, :details, :resource, :actor].index_with { |d| log.public_send(d) }
        expect(details).to eq(
          level: "info",
          channel: "download_your_data",
          event: action_name.to_s,
          details: { "controller" => described_class.name },
          resource: nil,
          actor: current_user
        )
      end
    end
  end

  it_behaves_like "audited action", :export do
    subject { post(target_path, params: { locale: I18n.default_locale }) }

    let(:target_path) { url_helpers.public_send(:export_download_your_data_path) }
  end
  it_behaves_like "audited action", :download_file do
    subject { get(target_path, params: { locale: I18n.default_locale }) }

    let(:target_path) { url_helpers.public_send(:download_file_download_your_data_path) }
  end
end
