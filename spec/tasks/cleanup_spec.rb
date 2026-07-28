# frozen_string_literal: true

require "spec_helper"

describe "rake decidim:audit:cleanup", type: :task do
  let(:cutoff_time) { 365.days.ago }
  let!(:old_records) do
    created_at = cutoff_time
    20.times.map do
      measure = [:hour, :day, :week].sample
      created_at -= rand(1..5).public_send(measure)
      create(:audit_log, created_at:)
    end
  end
  let!(:recent_records) do
    created_at = cutoff_time
    10.times.map do
      measure = [:hour, :day, :week].sample
      created_at += rand(1..5).public_send(measure)
      create(:audit_log, created_at:)
    end
  end

  it "cleans up the entries that are older than the default configuration" do
    expect(Decidim::Audit::Log.count).to eq(old_records.count + recent_records.count)
    expect { task.execute }.to change(Decidim::Audit::Log, :count).by(-old_records.count)
    expect(Decidim::Audit::Log.count).to eq(recent_records.count)
  end

  context "with the days argument" do
    let(:args) { Rake::TaskArguments.new(task.arg_names, ["30"]) }
    let(:cutoff_time) { 30.days.ago }

    it "cleans up the entries that are older than the provided argument" do
      expect(Decidim::Audit::Log.count).to eq(old_records.count + recent_records.count)
      expect { task.execute(args) }.to change(Decidim::Audit::Log, :count).by(-old_records.count)
      expect(Decidim::Audit::Log.count).to eq(recent_records.count)
    end
  end

  context "with different configured retention period" do
    let(:cutoff_time) { 30.days.ago }

    before do
      allow(Decidim::Audit).to receive(:retention_period_days).and_return(30)
    end

    it "cleans up the entries that are older than the provided argument" do
      expect(Decidim::Audit::Log.count).to eq(old_records.count + recent_records.count)
      expect { task.execute }.to change(Decidim::Audit::Log, :count).by(-old_records.count)
      expect(Decidim::Audit::Log.count).to eq(recent_records.count)
    end
  end
end
