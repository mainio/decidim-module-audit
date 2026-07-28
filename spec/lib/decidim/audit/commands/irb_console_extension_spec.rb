# frozen_string_literal: true

require "spec_helper"
require "decidim/audit/commands/irb_console_extension"

describe Decidim::Audit::Commands::IRBConsoleExtension do
  describe ".start" do
    subject { dummy_irb.start }

    let(:dummy_irb) do
      Module.new do
        class << self
          attr_reader :started

          def start
            @started = true
          end

          def started?
            started == true
          end
        end
      end
    end

    before do
      dummy_irb.include(described_class)
    end

    it "wraps the session correctly" do
      expect(Decidim::Audit::Commands::Session).to receive(:wrap).and_yield

      subject
      expect(dummy_irb.started?).to be(true)
    end
  end
end
