# frozen_string_literal: true

module Decidim
  module Audit
    module Logger
      # Formats hashes to JSON strings in the log output with the hash keys in
      # expected sorted order.
      class HashFormatter
        def initialize(hash)
          @hash = hash
        end

        def format
          sort_hash(hash).to_json
        end

        private

        attr_reader :hash

        def sort_hash(data)
          ActiveSupport::OrderedHash[data.sort].to_h do |key, value|
            value = sort_hash(value) if value.is_a?(Hash)
            value = sort_array_hashes(value) if value.is_a?(Array)

            [key, value]
          end
        end

        # Sorts the hash values within the array. Does not touch the order of
        # the array itself.
        def sort_array_hashes(array)
          array.map do |value|
            value = sort_hash(value) if value.is_a?(Hash)
            value = sort_array_hashes(value) if value.is_a?(Array)

            value
          end
        end
      end
    end
  end
end
