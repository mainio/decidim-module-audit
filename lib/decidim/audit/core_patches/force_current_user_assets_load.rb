# frozen_string_literal: true

module Decidim
  module Audit
    module CorePatches
      # This forces the user record's asset loads so that the current user is
      # not recorded as inspected user in the audited participant-side views
      # where the user record inspections are audited.
      #
      # Note that the AttachedUploaderCache and UploaderUrlCache patches are
      # required for this to work before the related PR is merged. And after
      # merged, this patch should not be needed either.
      #
      # REMOVE THIS AFTER THE FOLLOWING PR IS RELEASED:
      # https://github.com/decidim/decidim/pull/17599
      #
      # REF: decidim/decidim#17599
      module ForceCurrentUserAssetsLoad
        extend ActiveSupport::Concern

        included do
          prepend_around_action :force_asset_records_load
        end

        private

        def force_asset_records_load
          current_user.attached_uploader(:avatar).variant_url(:thumb)
          yield
        end
      end
    end
  end
end
