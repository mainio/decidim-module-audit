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
          message << "defails:#{format_hash(record.details)}" if record.details.present?
          message << "actor:#{record.actor_gid}" if record.actor_gid.present?
          message << "request:#{format_hash(record.request_details)}" if record.request_details.present?
          message << "resource:#{record.resource_type}##{record.resource_id}" if record.resource_type.present?
          message << "resource_changes:#{format_hash(record.resource_changes)}" if record.resource_changes.present?
          message.pop if message.last == ""
          message
        end

        private

        attr_reader :record

        def format_hash(hash)
          Decidim::Audit::Logger::HashFormatter.new(hash).format
        end
      end
    end
  end
end
