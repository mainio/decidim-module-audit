# frozen_string_literal: true

module Decidim
  module Audit
    module CorePatches
      # Caches the attached uploaders so that a new instance is not created on
      # every call.
      #
      # REMOVE THIS AFTER THE FOLLOWING PR IS RELEASED:
      # https://github.com/decidim/decidim/pull/17599
      #
      # REF: decidim/decidim#17599
      module AttachedUploaderCache
        def attached_uploader(attached_name)
          @attached_uploaders ||= {}
          @attached_uploaders[attached_name] ||= super
        end
      end
    end
  end
end
