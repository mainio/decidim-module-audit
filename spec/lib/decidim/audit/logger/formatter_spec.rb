# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Logger::Formatter do
  subject(:instance) { described_class.new }

  describe "#call" do
    subject { result }

    let(:result) { instance.call(severity, time, progname, msg) }

    let(:severity) { "SEVERITY" }
    let(:time) { Time.zone.now }
    let(:progname) { "progname" }
    let(:msg) { "message" }

    it "formats the message correctly" do
      expect(subject).to eq("#{format("%.1s", severity)}, [#{formatted_time(time)}] #{format("%-9s", severity)} -- #{progname}:   \n#{msg}\n")
    end

    context "with identified" do
      subject do
        instance.identified(123) do
          result
        end
      end

      it "formats the message correctly" do
        expect(subject).to eq("#{format("%.1s", severity)}, [#{formatted_time(time)}] #{format("%-9s", severity)} -- #{progname}: [123]   \n[123] #{msg}\n")
      end

      context "and tagged" do
        subject do
          instance.identified(123) do
            instance.tagged("foo", "bar") do
              result
            end
          end
        end

        it "formats the message correctly" do
          expect(subject).to eq("#{format("%.1s", severity)}, [#{formatted_time(time)}] #{format("%-9s", severity)} -- #{progname}: [123] [foo] [bar]   \n[123] #{msg}\n")
        end
      end
    end
  end

  describe "#identifier_text" do
    context "without identifier" do
      subject { instance.identifier_text }

      it { is_expected.to be_nil }
    end

    context "with identifier" do
      subject do
        instance.identified(123) { instance.identifier_text }
      end

      it { is_expected.to eq("[123] ") }
    end
  end

  describe "#tagged" do
    context "without identifier" do
      it "returns the current tags" do
        instance.tagged("foo", "bar") do
          expect(instance.current_tags).to eq(%w(foo bar))
        end
      end
    end

    context "with identifier" do
      it "returns the current tags and the identifier" do
        instance.identified(123) do
          instance.tagged("foo", "bar") do
            expect(instance.current_tags).to eq([123, "foo", "bar"])
          end
        end
      end
    end
  end

  describe "#identified" do
    it "defines the current identifier and clears it after the block" do
      expect(instance.current_identifier.get).to be_nil
      instance.identified(123) do
        expect(instance.current_identifier.get).to eq(123)
      end
      expect(instance.current_identifier.get).to be_nil
    end
  end

  describe "#current_identifier" do
    subject { instance.current_identifier }

    it { is_expected.to be_a(described_class::Identifier) }

    describe "#set" do
      before { subject.set(123) }

      it "sets the current identifier" do
        expect(subject.get).to eq(123)
      end
    end

    describe "#get" do
      it "sets the current identifier" do
        expect(subject.get).to be_nil
        subject.set(123)
        expect(subject.get).to eq(123)
      end
    end

    describe "#clear" do
      it "clears the current identifier" do
        subject.set(123)
        subject.clear
        expect(subject.get).to be_nil
      end
    end
  end

  def formatted_time(time)
    time.strftime(Logger::Formatter::DatetimeFormat)
  end
end
