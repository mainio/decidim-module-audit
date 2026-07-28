# frozen_string_literal: true

namespace :decidim do
  namespace :audit do
    desc "Export the DB logs to an audit log file"
    task :export_logs, [:start_time, :output_path] => :environment do |_, args|
      log_dir = File.dirname(Rails.application.config.paths["log"].first)
      FileUtils.mkdir_p(log_dir)

      start_time =
        begin
          Time.zone.parse(args.start_time) if args.start_time
        rescue StandardError
          puts "Invalid date provided."
          next
        end

      if start_time && !args.output_path
        puts "You must provide a custom output path when providing a start time."
        next
      end

      log_file_path = args.output_path || File.expand_path("#{Rails.env}_audit.log", log_dir)
      after = 0

      if File.exist?(log_file_path)
        buffer_size = 1024
        position = 0
        File.open(log_file_path, "r") do |file|
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
            if matches.any?
              after = matches.last[0].to_i
              break
            end

            break if position == -file.size
          end
        end
      end

      audit_logs =
        if start_time
          Decidim::Audit::Log.where("id > ? AND created_at >= ?", after, start_time)
        else
          Decidim::Audit::Log.where("id > ?", after)
        end
      if audit_logs.none?
        puts "No new logs to export."
        next
      end

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

      puts "Exported audit logs to: #{log_file_path}"
    end

    desc "Cleanup old audit logs after the configured retention period"
    task :cleanup, [:days] => :environment do |_, args|
      retention_period_days = args.days&.to_i || Decidim::Audit.retention_period_days

      cutoff_date = retention_period_days.days.ago

      Decidim::Audit::Log.where("created_at <= :cutoff", cutoff: cutoff_date).delete_all
    end
  end
end
