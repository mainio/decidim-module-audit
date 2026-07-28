# frozen_string_literal: true

require "spec_helper"

describe "rake decidim:audit:export_logs", type: :task do
  let!(:logs) do
    [
      create_list(:audit_log, 10, :with_full_details),
      create(:audit_log, :with_request, :with_visitor_actor),
      create(:audit_log, :with_system_actor)
    ].flatten
  end
  let(:users_logs) { Decidim::Audit::Log.where(channel: "decidim_users").to_a }
  let(:expected_log_entries) { logs + users_logs }
  let(:expected_output) do
    # The formatter is separately tested so we can rely that it produces the
    # correct expected output.
    formatter = Decidim::Audit::Logger::Formatter.new
    expected_log_entries.sort_by(&:id).map do |log|
      formatter.identified(log.id) do
        tags = []
        tags << "org-#{log.decidim_organization_id}" if log.decidim_organization_id
        tags << log.channel
        tags << log.event
        formatter.tagged(*tags) do
          msg = Decidim::Audit::Logger::RecordMessageFormatter.new(log).format

          formatter.call(log.level.upcase, log.created_at, "audit", msg)
        end
      end
    end.join
  end
  let(:log_file_path) { File.expand_path("log/test_audit.log", Decidim::Dev.dummy_app_path) }
  let(:log_output) { File.read(log_file_path) }

  after { FileUtils.rm_rf(log_file_path) }

  it "exports the existing log entries" do
    expect { task.execute }.not_to raise_error

    expect($stdout.string).to eq("Exported audit logs to: #{log_file_path}\n")

    expect(File.exist?(log_file_path)).to be(true)
    expect(log_output).to eq(expected_output)
  end

  context "when there are already written log entries" do
    let(:new_log_entries) { create_list(:audit_log, 5) }
    let(:expected_log_entries) { logs + users_logs + new_log_entries }

    it "exports only the new entries without duplicating the old entries" do
      expect { task.execute }.not_to raise_error
      expect(File.exist?(log_file_path)).to be(true)

      new_log_entries
      expect { task.execute }.not_to raise_error

      expect(log_output).to eq(expected_output)
    end
  end

  context "when the file exists but there are no log entries" do
    let(:initial_contents) { "\n" * 4000 }

    before do
      File.write(log_file_path, initial_contents)
    end

    it "exports the existing log entries" do
      expect { task.execute }.not_to raise_error

      expect($stdout.string).to eq("Exported audit logs to: #{log_file_path}\n")

      expect(File.exist?(log_file_path)).to be(true)
      expect(log_output).to eq(initial_contents + expected_output)
    end
  end

  context "when there are no log entries to export" do
    let!(:logs) { [] }

    it "does not do anything" do
      expect { task.execute }.not_to raise_error
      expect(File.exist?(log_file_path)).to be(false)

      expect($stdout.string).to eq("No new logs to export.\n")
    end
  end

  context "with the start time attribute" do
    let!(:logs) do
      [
        create_list(:audit_log, 10, created_at: provided_date - 1.day),
        create_list(:audit_log, 5, created_at: provided_date + 1.day)
      ].flatten
    end
    let(:expected_log_entries) { logs[-5..] }

    let(:args) { Rake::TaskArguments.new(task.arg_names, [date_string, log_file_path]) }
    let(:date_string) { provided_date.to_s }
    let(:log_file_path) { File.expand_path("tmp/custom.log", Decidim::Dev.dummy_app_path) }
    let(:provided_date) { 1.week.ago }

    it "exports only the logs after the provided date" do
      expect { task.execute(args) }.not_to raise_error

      expect($stdout.string).to eq("Exported audit logs to: #{log_file_path}\n")

      expect(File.exist?(log_file_path)).to be(true)
      expect(log_output).to eq(expected_output)
    end

    context "when there are already written log entries" do
      let(:new_log_entries) { create_list(:audit_log, 5, created_at: provided_date + 2.days) }
      let(:expected_log_entries) { logs[-5..] + new_log_entries }

      it "exports only the new entries without duplicating the old entries" do
        expect { task.execute(args) }.not_to raise_error
        expect(File.exist?(log_file_path)).to be(true)

        new_log_entries
        expect { task.execute(args) }.not_to raise_error

        expect(log_output).to eq(expected_output)
      end
    end

    context "without a path" do
      let(:args) { Rake::TaskArguments.new(task.arg_names, [date_string]) }

      it "assists the user to provide an output path" do
        expect { task.execute(args) }.not_to raise_error

        expect($stdout.string).to eq("You must provide a custom output path when providing a start time.\n")
      end
    end

    context "with invalid date" do
      let(:date_string) { provided_date.to_s.gsub("-", " ") }

      it "ends the process without exporting the logs" do
        expect { task.execute(args) }.not_to raise_error
        expect($stdout.string).to eq("Invalid date provided.\n")
        expect(File.exist?(log_file_path)).to be(false)
      end
    end
  end
end
