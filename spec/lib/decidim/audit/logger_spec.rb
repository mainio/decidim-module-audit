# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Logger do
  subject(:instance) do
    original_logger.level = described_class::INFO
    original_logger.formatter = described_class::Formatter.new
    described_class.new(original_logger)
  end

  let(:original_logger) { ActiveSupport::Logger.new(output, progname: "audit") }
  let(:output) { StringIO.new }

  describe ".new" do
    subject { described_class.new(original_logger) }

    it "returns a new instance with the extensions" do
      expect(subject.class).to eq(ActiveSupport::Logger)
      expect(subject).to be_a(ActiveSupport::TaggedLogging)
      expect(subject).to be_a(described_class)

      expect(subject).not_to eq(original_logger)
    end
  end

  describe "#identified" do
    subject do
      instance.identified(identifier) do
        instance.add(described_class::INFO, "testing", time:)
      end
      output.rewind
      output.read
    end

    let(:identifier) { 123 }
    let(:time) { Time.current }

    it "adds the identifier tag to the log" do
      expect(subject).to eq("I, [#{formatted_time(time)}] INFO      -- audit: [123]   \n[123] testing\n")
    end

    context "with tagged" do
      subject do
        instance.identified(identifier) do
          instance.tagged("foo", "bar") do
            instance.add(described_class::INFO, "testing", time:)
          end
        end
        output.rewind
        output.read
      end

      it "adds the identifier tag along with the other tags" do
        expect(subject).to eq("I, [#{formatted_time(time)}] INFO      -- audit: [123] [foo] [bar]   \n[123] testing\n")
      end
    end
  end

  describe "#flush" do
    let(:formatter) { instance.formatter }

    it "clears the current identifier" do
      instance.identified(123) do
        expect(formatter.current_identifier.get).to eq(123)
        instance.flush
        expect(formatter.current_identifier.get).to be_nil
      end
    end
  end

  describe "#add" do
    shared_examples "working log" do
      subject do
        instance.add(severity, "testing", time:)
        output.rewind
        output.read
      end

      let(:time) { Time.current }

      it "adds the log entry" do
        expect(subject).to eq("#{format("%.1s", severity_text)}, [#{formatted_time(time)}] #{format("%-9s", severity_text)} -- audit:   \ntesting\n")
      end

      context "with custom progname" do
        subject do
          instance.add(severity, "testing", "custom", time:)
          output.rewind
          output.read
        end

        it "adds the correct progname" do
          expect(subject).to eq("#{format("%.1s", severity_text)}, [#{formatted_time(time)}] #{format("%-9s", severity_text)} -- custom:   \ntesting\n")
        end
      end

      context "with the message provided at the progname position" do
        subject do
          instance.add(severity, nil, "testing", time:)
          output.rewind
          output.read
        end

        it "adds the log entry" do
          expect(subject).to eq("#{format("%.1s", severity_text)}, [#{formatted_time(time)}] #{format("%-9s", severity_text)} -- audit:   \ntesting\n")
        end
      end

      context "with a block" do
        subject do
          instance.add(severity, time:) do
            "block message"
          end
          output.rewind
          output.read
        end

        it "gets the message from the block" do
          expect(subject).to eq("#{format("%.1s", severity_text)}, [#{formatted_time(time)}] #{format("%-9s", severity_text)} -- audit:   \nblock message\n")
        end
      end

      context "when the log configured log level is higher than severity" do
        before do
          instance.level = severity + 1
        end

        it "does not output anything" do
          expect(subject).to eq("")
        end
      end
    end

    %w(INFO NOTICE WARN ERROR CRITICAL ALERT FATAL).each do |level|
      context "with #{level}" do
        let(:severity) { described_class.const_get(level) }
        let(:severity_text) { level }

        it_behaves_like "working log"
      end
    end

    context "with UNKNOWN" do
      let(:severity) { described_class::UNKNOWN }
      let(:severity_text) { "ANY" }

      it_behaves_like "working log"
    end
  end

  def formatted_time(time)
    time.strftime(Logger::Formatter::DatetimeFormat)
  end
end
