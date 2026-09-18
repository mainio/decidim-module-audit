# frozen_string_literal: true

module Decidim
  module Audit
    # Custom extension to manage the conversation inspections and logging the
    # inspected user records for those conversations.
    module ConversationsControllerExtension
      extend ActiveSupport::Concern

      included do
        # rubocop:disable Rails/LexicallyScopedActionFilter
        after_action :audit_read_with_users, only: [:index, :show, :new]
        around_action :audit_create, only: [:create]
        after_action :audit_read, only: [:update]
        # rubocop:enable Rails/LexicallyScopedActionFilter
      end

      private

      def audit_read_with_users
        return unless response.response_code == 200

        resource = nil
        conversation_ids = nil
        participant_ids = nil
        case action_name.to_sym
        when :index
          conversation_ids = @conversations.pluck(:id)
        when :new
          participant_ids = @form.recipient.pluck(:id)
        when :show
          resource = @conversation
        end

        Decidim::Audit.log(
          channel: "conversations",
          event: action_name,
          details: { controller: self.class.name, ids: conversation_ids }.compact,
          level: :info,
          resource:
        )

        participant_ids ||= Decidim::Messaging::Participation.where(
          conversation: conversation_ids || resource
        ).where.not(
          decidim_participant_id: current_user.id
        ).pluck(:decidim_participant_id)
        return if participant_ids.blank?

        if participant_ids.length == 1
          Decidim::Audit.log(
            channel: "decidim_users",
            event: :read,
            level: :info,
            resource_type: Decidim::UserBaseEntity.polymorphic_name,
            resource_id: participant_ids.first
          )
        else
          Decidim::Audit.log(
            channel: "decidim_users",
            event: :read,
            level: :info,
            details: { ids: participant_ids }
          )
        end
      end

      def audit_create
        extend(CreateActionOverride)

        yield

        audit_read
      end

      def audit_read
        Decidim::Audit.log(
          channel: "conversations",
          event: action_name,
          details: { controller: self.class.name },
          level: :info,
          resource: @conversation
        )
      end

      # Overrides for the controller instance during the create action in order
      # to get access to the created conversation object which is only passed as
      # "locals" to the render call.
      module CreateActionOverride
        def render_to_body(options = {})
          locals = options[:locals]
          @conversation = locals[:conversation] if locals

          super
        end
      end
    end
  end
end
