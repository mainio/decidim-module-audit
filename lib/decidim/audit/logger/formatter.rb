# frozen_string_literal: true

module Decidim
  module Audit
    module Logger
      # Formats the log messages so that each line of the log can be identified
      # with a specific log entry. For example, given the following code:
      #
      #   logger = ActiveSupport::Logger.new("log/audit.log", progname: "decidim-audit")
      #   logger.level = ActiveSupport::Logger::INFO
      #   logger.formatter = Decidim::Audit::Logger::Formatter.new
      #
      #   logger.identified(123) do
      #     logger.tagged("tag1", "tag2") do
      #       logger.info(["Hello", "to", "logs"])
      #     end
      #   end
      #
      # The resulting output would be as follows:
      #
      #   I, [2026-07-26T12:00:00.000000 #9876] INFO -- decidim-audit: [123] [tag1] [tag2]
      #   [123] Hello
      #   [123] to
      #   [123] logs
      #
      # Uses the default format defined by `Logger::Formatter::Format` that also
      # logs the log level, timestamp, and the process ID where this was logged.
      class Formatter < ::Logger::Formatter
        include ActiveSupport::TaggedLogging::Formatter

        FORMAT = "%.1s, [%s] %-9s -- %s: %s\n"

        def call(severity, time, progname, msg)
          msg = msg.split("\n") unless msg.is_a?(Array)

          msg.unshift("  ")
          msg = msg.join("\n#{identifier_text}")

          all_tags = tags_text
          all_tags ||= identifier_text

          format(FORMAT, severity, format_datetime(time), severity, progname, msg2str("#{all_tags}#{msg}"))
        end

        def identifier_text
          "[#{current_identifier.get}] " if current_identifier.get.present?
        end

        def tagged(*tags)
          super(*([current_identifier.get] + tags))
        end

        def identified(identifier)
          current_identifier.set identifier
          yield self
        ensure
          current_identifier.clear
        end

        def current_identifier
          @identifier_thread_key ||= "decidim_audit_logging_identifier:#{object_id}"
          ActiveSupport::IsolatedExecutionState[@identifier_thread_key] ||= Identifier.new
        end

        class Identifier
          def set(identifier)
            @current_identifier = identifier
          end

          def get
            @current_identifier
          end

          def clear
            remove_instance_variable(:@current_identifier) if instance_variable_defined?(:@current_identifier)
          end
        end
      end
    end
  end
end
