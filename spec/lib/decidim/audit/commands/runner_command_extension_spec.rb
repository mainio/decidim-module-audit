# frozen_string_literal: true

require "spec_helper"
require "rails/command"
require "rails/commands/runner/runner_command"
require "decidim/audit/commands/runner_command_extension"
require "active_support/testing/stream"

describe Decidim::Audit::Commands::RunnerCommandExtension do
  include ActiveSupport::Testing::Stream

  subject(:command) { runner_class.new }

  let(:runner_class) { Rails::Command::RunnerCommand }

  describe "Rails::Command::RunnerCommand#perform" do
    context "with code passed" do
      subject { capture(:stdout) { command.perform(%(print "test")) } }

      it "wraps the session correctly" do
        expect(Decidim::Audit::Commands::Session).to receive(:wrap).and_yield

        expect(subject).to eq("test")
      end
    end

    context "with file passed" do
      subject { capture(:stdout) { command.perform(file_fixture("runner_example.rb")) } }

      it "wraps the session correctly" do
        expect(Decidim::Audit::Commands::Session).to receive(:wrap).and_yield

        expect(subject).to eq("Example file for testing.")
      end
    end
  end
end
