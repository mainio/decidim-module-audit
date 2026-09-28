# frozen_string_literal: true

module Decidim
  module Audit
    module Logger
      # Exports new logs to the defined log path and reads the last logged
      # record from the output file which defines cutoff position after which
      # new records are exported.
      class Exporter
        def initialize(log_file_path, start_time: nil)
          raise ArgumentError, "Invalid start time provided" if start_time && !start_time.is_a?(Time)

          @log_file_path = log_file_path
          @start_time = start_time
        end

        def export
          return nil if audit_logs.none?

          File.open(log_file_path, "a") do |log_file|
            log_file.binmode
            log_file.sync = true # if true make sure every write flushes

            logger = ActiveSupport::Logger.new(log_file, progname: "audit")
            logger.level = Decidim::Audit::Logger::INFO
            logger.formatter = Decidim::Audit::Logger::Formatter.new
            logger = Decidim::Audit::Logger.new(logger)

            audit_logs.order(:id).each do |log|
              logger.identified(log.id) do
                tags = []
                tags << "org-#{log.decidim_organization_id}" if log.decidim_organization_id
                tags << log.channel
                tags << log.event
                logger.tagged(*tags) do
                  message = Decidim::Audit::Logger::RecordMessageFormatter.new(log).format

                  logger.add(log.logger_level, message, time: log.created_at)
                end
              end
            end

            logger
          end

          audit_logs.count
        end

        private

        attr_reader :log_file_path, :start_time

        def audit_logs
          @audit_logs ||= begin
            after = last_exported_id || 0
            if start_time
              Decidim::Audit::Log.where("id > ? AND created_at >= ?", after, start_time)
            else
              Decidim::Audit::Log.where("id > ?", after)
            end
          end
        end

        def last_exported_id
          last_id = find_last_exported_id(log_file_path)
          return last_id if last_id

          # Try the next rotated log file in case there are no log entries in
          # the currently active log.
          find_last_exported_id("#{log_file_path}.1")
        end

        def find_last_exported_id(file_path)
          return unless File.exist?(file_path)

          buffer_size = 1024
          position = 0
          File.open(file_path, "r") do |file|
            while position >= -file.size
              if position - buffer_size < -file.size
                buffer_size = file.size + position
                position = -file.size
              else
                position -= buffer_size
              end

              chunk = file.pread(buffer_size, file.size + position)

              # Match the beginning lines of the log entries and find the last
              # logged entry.
              matches = chunk.scan(
                /[INWECAF], \[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{6}\] [A-Z]{4,9}[ ]{1,6} -- audit: \[([0-9]+)\]/
              )
              return matches.last[0].to_i if matches.any?

              break if position == -file.size
            end
          end

          nil
        end
      end
    end
  end
end
