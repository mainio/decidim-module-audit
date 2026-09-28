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

      exporter = Decidim::Audit::Logger::Exporter.new(log_file_path, start_time:)
      if exporter.export
        puts "Exported audit logs to: #{log_file_path}"
      else
        puts "No new logs to export."
        next
      end
    end

    desc "Cleanup old audit logs after the configured retention period"
    task :cleanup, [:days] => :environment do |_, args|
      retention_period_days = args.days&.to_i || Decidim::Audit.retention_period_days

      cutoff_date = retention_period_days.days.ago

      Decidim::Audit::Log.where("created_at <= :cutoff", cutoff: cutoff_date).delete_all
    end
  end
end
