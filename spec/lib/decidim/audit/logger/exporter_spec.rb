# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Logger::Exporter do
  subject(:instance) { described_class.new(log_file_path, start_time:) }

  let(:log_file_path) { File.expand_path("log/test_audit.log", Decidim::Dev.dummy_app_path) }
  let(:start_time) { nil }

  describe "#initialize" do
    context "when the start time is not a time" do
      let(:start_time) { Time.current.iso8601 }

      it "raises an ArgumentError" do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end
end
