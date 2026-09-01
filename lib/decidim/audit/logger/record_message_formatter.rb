# frozen_string_literal: true

module Decidim
  module Audit
    module Logger
      # Formats a database log record as a message for the log output.
      class RecordMessageFormatter
        def initialize(record)
          @record = record
        end

        def format
          message = []
          message += [record.message, ""] if record.message.present?
          message_items.each do |key, value|
            message << "#{key}:#{value}"
          end
          message.pop if message.last == ""
          message
        end

        private

        attr_reader :record

        def format_hash(hash)
          return unless hash.is_a?(Hash)
          return if hash.blank?

          Decidim::Audit::Logger::HashFormatter.new(hash).format
        end

        def format_array(array)
          return unless array.is_a?(Array)
          return if array.blank?

          array.join(",")
        end

        def format_resource(resource_type, resource_id)
          return if resource_type.blank?

          "#{resource_type}##{resource_id}"
        end

        def message_items
          ActiveSupport::OrderedHash[
            {
              details: format_hash(record.details),
              actor_type: record.actor_type,
              actor: record.actor_gid,
              actor_roles: format_array(record.actor_roles),
              request: format_hash(record.request_details),
              resource: format_resource(record.resource_type, record.resource_id),
              resource_changes: format_hash(record.resource_changes)
            }
          ].compact
        end
      end
    end
  end
end
