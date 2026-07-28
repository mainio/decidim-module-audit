# frozen_string_literal: true

module Decidim
  module Audit
    module Logger
      autoload :Formatter, "decidim/audit/logger/formatter"
      autoload :HashFormatter, "decidim/audit/logger/hash_formatter"
      autoload :RecordMessageFormatter, "decidim/audit/logger/record_message_formatter"

      INFO = 0
      NOTICE = 1
      WARN = 2
      ERROR = 3
      CRITICAL = 4
      ALERT = 5
      FATAL = 6
      UNKNOWN = 7

      def self.new(logger)
        logger = logger.clone

        logger.formatter = logger.formatter.dup
        logger.extend(ActiveSupport::TaggedLogging)
        logger.extend(self)
      end

      def identified(identifier)
        formatter.identified(identifier) { yield self }
      end

      def flush
        formatter.current_identifier.clear
        super
      end

      # Overridden to pass the time of the event.
      def add(severity, message = nil, progname = nil, time: Time.zone.now)
        severity ||= UNKNOWN
        return true if @logdev.nil? || severity < level

        progname = @progname if progname.nil?
        if message.nil?
          if block_given?
            message = yield
          else
            message = progname
            progname = @progname
          end
        end
        @logdev.write(
          format_message(format_severity(severity), time, progname, message)
        )
        true
      end
      alias log add

      private

      SEV_LABEL = %w(INFO NOTICE WARN ERROR CRITICAL ALERT FATAL ANY).freeze

      def format_severity(severity)
        SEV_LABEL[severity] || "ANY"
      end
    end
  end
end
