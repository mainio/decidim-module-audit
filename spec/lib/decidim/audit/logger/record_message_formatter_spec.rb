# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Logger::RecordMessageFormatter do
  subject(:instance) { described_class.new(record) }

  describe "#format" do
    subject { instance.format }

    context "with full details" do
      let(:record) { create(:audit_log, :with_full_details) }
      let(:expected_message) do
        [
          record.message,
          "",
          "defails:#{format_hash(record.details)}",
          "actor:#{record.actor_gid}",
          "request:#{format_hash(record.request_details)}",
          "resource:#{record.resource_type}##{record.resource_id}",
          "resource_changes:#{format_hash(record.resource_changes)}"
        ]
      end

      it { is_expected.to eq(expected_message) }
    end

    context "without message" do
      let(:record) { create(:audit_log, :with_full_details, message: nil) }
      let(:expected_message) do
        [
          "defails:#{format_hash(record.details)}",
          "actor:#{record.actor_gid}",
          "request:#{format_hash(record.request_details)}",
          "resource:#{record.resource_type}##{record.resource_id}",
          "resource_changes:#{format_hash(record.resource_changes)}"
        ]
      end

      it { is_expected.to eq(expected_message) }
    end

    context "with only message" do
      let(:record) { create(:audit_log, message: "Message.") }
      let(:expected_message) { ["Message."] }

      it { is_expected.to eq(expected_message) }
    end
  end

  def format_hash(hash)
    Decidim::Audit::Logger::HashFormatter.new(hash).format
  end
end
