# frozen_string_literal: true

module Decidim
  module Audit
    module CorePatches
      # This fixes an issue with the Decidim::FollowingCell querying all
      # followed users instead of only the displayed amount.
      #
      # REMOVE THIS AFTER THE FOLLOWING PR IS RELEASED:
      # https://github.com/decidim/decidim/pull/17700
      #
      # REF: decidim/decidim#17700
      module FollowingCellFix
        extend ActiveSupport::Concern

        included do
          def public_followings
            @public_followings ||=
              model
              .public_users_followings
              .order("decidim_follows.created_at", "decidim_follows.id")
              .page(params[:page]).per(20)
          end
        end
      end
    end
  end
end
