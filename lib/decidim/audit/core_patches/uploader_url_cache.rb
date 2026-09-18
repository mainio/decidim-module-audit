# frozen_string_literal: true

module Decidim
  module Audit
    module CorePatches
      # Caches the generated variant URLs for a specific record while the same
      # object is referenced, e.g. during view rendering and referring to
      # current_user.
      #
      # REMOVE THIS AFTER THE FOLLOWING PR IS RELEASED:
      # https://github.com/decidim/decidim/pull/17599
      #
      # REF: decidim/decidim#17599
      module UploaderUrlCache
        def variant_url(key, options = {})
          @variant_urls ||= {}

          cache_key = ActiveSupport::Cache.expand_cache_key([key, options]).sub(%r{/\z}, "")
          return @variant_urls[cache_key] if @variant_urls.has_key?(cache_key)

          @variant_urls[cache_key] = super
        end
      end
    end
  end
end
