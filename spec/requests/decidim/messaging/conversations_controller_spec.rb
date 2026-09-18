# frozen_string_literal: true

require "spec_helper"

describe Decidim::Messaging::ConversationsController do
  subject { get(target_path, params: { locale: I18n.default_locale }) }

  include_context "with auditable user read controller"

  let(:url_helpers) { Decidim::Core::Engine.routes.url_helpers }
  let(:current_user) { create(:user, :confirmed, organization:) }

  shared_examples "working single conversation with users" do
    it "logs the action and the queried user records" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      expect(log_details(logs[0])).to eq(
        level: "info",
        channel: "conversations",
        event: action_name,
        details: { "controller" => described_class.name },
        resource: try(:conversation),
        actor: current_user
      )

      if expected_users.length > 1
        log = log_details(logs[1])
        expect(log).to match(
          level: "info",
          channel: "decidim_users",
          event: "read",
          details: { "ids" => an_instance_of(Array) },
          resource: nil,
          actor: current_user
        )
        expect(log[:details]["ids"]).to match_array(expected_users.map(&:id))
      else
        expect(log_details(logs[1])).to eq(
          level: "info",
          channel: "decidim_users",
          event: "read",
          details: nil,
          resource: expected_users[0],
          actor: current_user
        )
      end
    end
  end

  shared_examples "working single conversation" do
    it "logs the action" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.order(:id).last
      expect(log_details(log)).to eq(
        level: "info",
        channel: "conversations",
        event: action_name,
        details: { "controller" => described_class.name },
        resource: conversation,
        actor: current_user
      )
    end
  end

  describe "#index" do
    let(:target_path) { url_helpers.conversations_path }

    let(:originators) { create_list(:user, 5, :confirmed, organization:) }
    let(:recipients) { create_list(:user, 3, :confirmed, organization:) }
    let(:group_originator) { create(:user, :confirmed, organization:) }
    let(:group_interluctor) { create(:user, :confirmed, organization:) }
    let(:group_recipients) { create_list(:user, 2, :confirmed, organization:) }
    let!(:conversations) do
      originators.map { |originator| create(:conversation, originator:, interlocutors: [current_user]) } +
        recipients.map { |recipient| create(:conversation, originator: current_user, interlocutors: [recipient]) } +
        [
          create(:conversation, originator: group_originator, interlocutors: [current_user, group_interluctor]),
          create(:conversation, originator: current_user, interlocutors: group_recipients)
        ]
    end

    it "logs the action and the queried user records" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      log = log_details(logs[0])
      expect(log).to match(
        level: "info",
        channel: "conversations",
        event: "index",
        details: { "controller" => described_class.name, "ids" => an_instance_of(Array) },
        resource: nil,
        actor: current_user
      )
      expect(log[:details]["ids"]).to match_array(conversations.map(&:id))

      log = log_details(logs[1])
      expect(log).to match(
        level: "info",
        channel: "decidim_users",
        event: "read",
        details: { "ids" => an_instance_of(Array) },
        resource: nil,
        actor: current_user
      )
      expect(log[:details]["ids"]).to match_array(
        originators.map(&:id) +
          recipients.map(&:id) +
          [group_originator.id, group_interluctor.id] +
          group_recipients.map(&:id)
      )
    end
  end

  describe "#show" do
    let(:target_path) { url_helpers.conversation_path(conversation) }
    let(:action_name) { "show" }

    it_behaves_like "working single conversation with users" do
      let!(:conversation) { create(:conversation, originator: current_user, interlocutors: [recipient]) }
      let(:recipient) { create(:user, :confirmed, organization:) }
      let(:expected_users) { [recipient] }
    end

    context "when the current user is a recipient" do
      it_behaves_like "working single conversation with users" do
        let!(:conversation) { create(:conversation, originator:, interlocutors: [current_user]) }
        let(:originator) { create(:user, :confirmed, organization:) }
        let(:expected_users) { [originator] }
      end
    end

    context "with a group conversation" do
      it_behaves_like "working single conversation with users" do
        let!(:conversation) { create(:conversation, originator: current_user, interlocutors: expected_users) }
        let(:expected_users) { create_list(:user, 2, :confirmed, organization:) }
      end

      context "when the current user is a recipient" do
        it_behaves_like "working single conversation with users" do
          let!(:conversation) { create(:conversation, originator:, interlocutors: [current_user, recipient]) }
          let(:originator) { create(:user, :confirmed, organization:) }
          let(:recipient) { create(:user, :confirmed, organization:) }
          let(:expected_users) { [originator, recipient] }
        end
      end
    end
  end

  describe "#new" do
    let(:target_path) { url_helpers.new_conversation_path(recipient_id: recipient.id) }
    let(:action_name) { "new" }

    it_behaves_like "working single conversation with users" do
      let!(:recipient) { create(:user, :confirmed, organization:) }
      let(:expected_users) { [recipient] }
    end

    context "with multiple recipients" do
      let(:target_path) { url_helpers.new_conversation_path(recipient_id: recipients.map(&:id)) }
      let!(:recipients) { create_list(:user, 2, :confirmed, organization:) }

      it_behaves_like "working single conversation with users" do
        let(:expected_users) { recipients }
      end
    end

    context "when the conversation already exists between the participants" do
      let!(:conversation) { create(:conversation, originator: current_user, interlocutors: [recipient]) }
      let(:recipient) { create(:user, :confirmed, organization:) }

      it "does not log anything" do
        expect { subject }.not_to change(Decidim::Audit::Log, :count)
      end
    end
  end

  describe "#create" do
    subject do
      post(
        target_path,
        params: {
          locale: I18n.default_locale,
          format: :js,
          recipient_id: recipient.id,
          body: "This is a new conversation."
        }
      )
    end

    let(:target_path) { url_helpers.conversations_path }
    let(:action_name) { "create" }

    it_behaves_like "working single conversation" do
      let(:conversation) { Decidim::Messaging::Conversation.order(:id).last }
      let!(:recipient) { create(:user, :confirmed, organization:) }
    end
  end

  describe "#update" do
    subject do
      patch(
        target_path,
        params: {
          locale: I18n.default_locale,
          format: :js,
          body: "This is a new message."
        }
      )
    end

    let(:target_path) { url_helpers.conversation_path(conversation) }
    let(:action_name) { "update" }

    it_behaves_like "working single conversation" do
      let!(:conversation) { create(:conversation, originator: current_user, interlocutors: [recipient]) }
      let(:recipient) { create(:user, :confirmed, organization:) }
    end
  end
end
