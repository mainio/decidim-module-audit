# frozen_string_literal: true

module Decidim
  module Audit
    # ! ! ! REPLACE THIS AFTER PR #17558 IS RELEASED ! ! !
    #
    # This implements custom audit functionality for the admin reports
    # controller as it currently queries all conversations and their
    # participants due to the inefficient handling of finding the conversation
    # record between the reportable item's author and the current admin user.
    # Therefore, when using the automatic ControllerAuditUserRead concern, the
    # reports controller would log all these user fetches, which is more users
    # than what are displayed because it searches through all the conversations
    # for the given user and matches if there is any existing conversation
    # between that user and the current admin user. This is inefficient and the
    # wrong way to do it and there is an upcoming fix to this issue at:
    # https://github.com/decidim/decidim/pull/17558
    #
    # After merged, see the comments at `engine.rb` for replacing this concern
    # with the generalized one.
    module AdminReportsControllerExtension
      extend ActiveSupport::Concern

      included do
        before_action :index, :audit_read
      end

      private

      def audit_read
        Decidim::Audit.log(
          channel: "users_admin",
          event: action_name,
          details: { controller: self.class.name },
          level: :info
        )

        reportable = moderation.reportable
        reportable_authors = reportable.try(:authors)
        reportable_authors ||=
          # 0.31 onwards, remove the `normalized_author` check and call.
          if reportable.respond_to?(:normalized_author)
            [reportable.normalized_author]
          else
            [reportable.try(:author)]
          end

        record_ids = reportable_authors.map(&:id)
        return if record_ids.blank?

        if record_ids.length == 1
          Decidim::Audit.log(
            channel: "decidim_users",
            event: :read,
            level: :info,
            resource: reportable_authors.first
          )
        else
          Decidim::Audit.log(
            channel: "decidim_users",
            event: :read,
            level: :info,
            details: { ids: record_ids }
          )
        end
      end
    end
  end
end
