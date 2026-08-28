# frozen_string_literal: true

shared_context "with auditable authorization workflow controller" do
  let(:organization) { create(:organization, available_authorizations: [workflow_name]) }
  let(:current_user) { create(:user, :admin, :confirmed, organization:) }

  before do
    host! organization.host
    login_as current_user, scope: :user

    # Ensures that authentication events are not logged during the actual test
    # request.
    get("/", params: { locale: I18n.default_locale })
  end

  def log_details(log)
    [:level, :channel, :event, :details, :resource, :actor].index_with { |detail| log.public_send(detail) }
  end
end

shared_examples "audit authorization workflow admin controller list" do |action_name = :index|
  let!(:users) { create_list(:user, 30, :confirmed, organization:) }
  let(:queried_amount_per_page) { Decidim::Paginable::OPTIONS.first }
  let(:audit_authorizations) { true }
  let(:audits_users) { false }

  include_context "with auditable authorization workflow controller"

  describe "##{action_name}" do
    subject { get(target_path, params: { locale: I18n.default_locale }) }

    it "audits the action and reads to audited records" do
      expected_amount = 1
      expected_amount += 1 if audit_authorizations
      expected_amount += 1 if audits_users
      expect { subject }.to change(Decidim::Audit::Log, :count).by(expected_amount)

      logs = Decidim::Audit::Log.order(:id).last(expected_amount)
      expect(log_details(logs[0])).to eq(
        level: "info",
        channel: "authorizations_admin",
        event: action_name.to_s,
        details: { "workflow" => workflow_name }.compact,
        resource: nil,
        actor: current_user
      )

      if audits_users
        expect(log_details(logs[1])).to match(
          level: "info",
          channel: "decidim_users",
          event: "read_list",
          details: { "ids" => an_instance_of(Array) },
          resource: nil,
          actor: current_user
        )
        expect(logs[1].details["ids"]).to match_array(users.map(&:id))
      end

      if audit_authorizations
        log = audits_users ? logs[2] : logs[1]
        expect(log_details(log)).to match(
          level: "info",
          channel: "decidim_authorizations",
          event: "read_list",
          details: { "ids" => an_instance_of(Array) },
          resource: nil,
          actor: current_user
        )
        expect(log.details["ids"]).to match_array(authorizations.map(&:id))
      end
    end
  end
end

shared_examples "audit authorization workflow admin controller action" do |action_name = :show|
  include_context "with auditable authorization workflow controller"

  describe "##{action_name}" do
    subject { get(target_path, params: { locale: I18n.default_locale }) }

    it "audits the action" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.order(:id).last
      expect(log_details(log)).to eq(
        level: "info",
        channel: "authorizations_admin",
        event: action_name.to_s,
        details: { "workflow" => workflow_name }.compact,
        resource: nil,
        actor: current_user
      )
    end
  end
end

shared_examples "audit authorization workflow admin controller action and authorization" do |action_name = :show|
  include_context "with auditable authorization workflow controller"

  describe "##{action_name}" do
    subject { get(target_path, params: { locale: I18n.default_locale }) }

    it "audits the action" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      expect(log_details(logs[0])).to eq(
        level: "info",
        channel: "authorizations_admin",
        event: action_name.to_s,
        details: { "workflow" => workflow_name }.compact,
        resource: nil,
        actor: current_user
      )
      expect(log_details(logs[1])).to eq(
        level: "info",
        channel: "decidim_authorizations",
        event: "read",
        details: nil,
        resource: authorization,
        actor: current_user
      )
    end
  end
end
