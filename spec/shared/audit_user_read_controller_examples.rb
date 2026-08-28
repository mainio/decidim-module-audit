# frozen_string_literal: true

shared_context "with auditable user read controller" do
  let(:organization) { create(:organization) }
  let!(:admins) { create_list(:user, 1, :admin, :confirmed, organization:) }
  let(:current_user) { admins[0] }

  let(:url_helpers) { Decidim::Admin::Engine.routes.url_helpers }

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

shared_examples "audit user read controller list" do |action_name = :index|
  let(:queried_amount_per_page) { Decidim::Paginable::OPTIONS.first }

  describe "##{action_name}" do
    subject { get(target_path, params: { locale: I18n.default_locale }) }

    # Ensure the `target_path` method creates any records before the test.
    before { target_path }

    it "logs the action and the list of inspected users within the view" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      expect(log_details(logs[0])).to eq(
        level: "info",
        channel: "users_admin",
        event: action_name.to_s,
        details: { "controller" => described_class.name },
        resource: nil,
        actor: current_user
      )
      expect(log_details(logs[1])).to match(
        level: "info",
        channel: "decidim_users",
        event: "read_list",
        details: { "ids" => an_instance_of(Array) },
        resource: nil,
        actor: current_user
      )
      expect(logs[1].details["ids"].count).to eq(queried_amount_per_page)
      expect(queried_users.map(&:id)).to include(*logs[1].details["ids"])
    end
  end
end

shared_examples "audit user read controller single" do |action_name = :show|
  describe "##{action_name}" do
    subject { get(target_path, params: { locale: I18n.default_locale }) }

    # Ensure the `target_path` method creates any records before the test.
    before { target_path }

    it "logs the action and the inspected user" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      expect(log_details(logs[0])).to eq(
        level: "info",
        channel: "users_admin",
        event: action_name.to_s,
        details: { "controller" => described_class.name },
        resource: nil,
        actor: current_user
      )
      if respond_to?(:target_users)
        expect(log_details(logs[1])).to match(
          level: "info",
          channel: "decidim_users",
          event: "read",
          details: { "ids" => an_instance_of(Array) },
          resource: nil,
          actor: current_user
        )
        expect(logs[1].details["ids"]).to match_array(target_users.map(&:id))
      else
        expect(log_details(logs[1])).to match(
          level: "info",
          channel: "decidim_users",
          event: "read",
          details: nil,
          resource: target_user,
          actor: current_user
        )
      end
    end
  end
end

shared_examples "audit user read for moderation reports" do
  include_context "with auditable user read controller" do
    context "with a single author" do
      let!(:component) { create(:post_component, participatory_space:) }
      let(:reportable) { create(:post, component:, author: target_user) }
      let!(:moderation) do
        moderation = create(:moderation, reportable:, report_count: 1, reported_content: reportable.reported_searchable_content_text)
        create(:report, moderation:)
        moderation
      end
      let(:target_path) { reports_path }
      let(:target_user) { create(:user, :confirmed, organization:) }

      it_behaves_like "audit user read controller single", :index

      # Remove this branch of the test after the `normalized_author` method is
      # removed from the core (0.31 onwards).
      context "when not responding to #normalized_author" do
        let!(:component) { create(:component, participatory_space:) }
        let(:reportable_class) { self.class.const_get(:DummyResource) }
        let(:reportable) do
          reportable_class.create!(
            title: Decidim::Faker::Localized.literal("Title"),
            component:,
            author: target_user
          )
        end

        around do |example|
          klass = Class.new(Decidim::Dev::ApplicationRecord) do
            self.table_name = "decidim_dev_dummy_resources"

            include Decidim::HasComponent
            include Decidim::Authorable
            include Decidim::Reportable
            include Decidim::TranslatableResource

            undef_method :normalized_author

            translatable_fields :title

            def reported_attributes
              [:title]
            end

            def reported_content_url(_options = {})
              "#"
            end
          end
          self.class.const_set(:DummyResource, klass)

          example.run

          self.class.class_eval do
            remove_const(:DummyResource)
          end
        end

        it_behaves_like "audit user read controller single", :index
      end
    end

    context "with multiple authors" do
      it_behaves_like "audit user read controller single", :index do
        let(:target_path) { reports_path }
        let(:target_users) { create_list(:user, 2, :confirmed, organization:) }

        let(:component) { create(:proposal_component, participatory_space:) }
        let(:reportable) { create(:proposal, :published, component:, users: target_users) }
        let(:proposal) { create(:proposal, component:) }
        let!(:moderation) do
          moderation = create(:moderation, reportable:, report_count: 1, reported_content: reportable.reported_searchable_content_text)
          create(:report, moderation:)
          moderation
        end
      end
    end
  end
end
