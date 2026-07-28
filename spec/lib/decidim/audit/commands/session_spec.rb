# frozen_string_literal: true

require "spec_helper"
require "decidim/audit/commands/session"

describe Decidim::Audit::Commands::Session do
  let(:session) { described_class.new }

  let!(:admin) { create(:admin, email:, password:, password_confirmation: password) }
  let(:email) { "system@example.org" }
  let(:provided_email) { email }
  let(:password) { "decidim123456789" }
  let(:provided_password) { password }

  shared_context "with stubbed input and output" do
    let(:input) { double }
    let(:output) { StringIO.new }

    before do
      allow(described_class).to receive(:const_get) do |name|
        if name == "STDIN"
          input
        elsif name == "STDOUT"
          output
        end
      end

      allow(input).to receive(:tty?).and_return(false)
      allow(input).to receive(:gets).and_return(provided_email, provided_password)
      allow(input).to receive(:noecho).and_return(provided_password)
    end
  end

  shared_examples "working console login" do |tty_mode: false|
    let(:expected_output) do
      if tty_mode
        <<~OUT.strip
          To perform commands from the console, you need to login with a SYSTEM user.
          Email: Password:
        OUT
      else
        <<~OUT.strip
          To perform commands from the console, you need to login with a SYSTEM user.
          Email: #{provided_email}
          Password:
        OUT
      end
    end

    context "with correct credentials" do
      it "returns the correct output" do
        subject
        output.rewind
        expect(output.read.strip).to eq(expected_output)
      end
    end

    shared_examples "incorrect credentials" do
      it "returns the correct output" do
        subject
        output.rewind
        expect(output.read.strip).to eq(
          <<~OUT.strip
            #{expected_output}#{" "}
            Invalid email or password.
          OUT
        )
      end
    end

    context "with incorrect email" do
      let(:provided_email) { "unexisting@example.org" }

      it_behaves_like "incorrect credentials"
    end

    context "with incorrect password" do
      let(:provided_password) { "invalid" }

      it_behaves_like "incorrect credentials"
    end

    context "when interrupting" do
      it "interrupts with a clean message" do
        allow(input).to receive(:gets).and_raise(Interrupt)
        subject

        output.rewind
        expect(output.read.strip).to eq(
          <<~OUT.strip
            To perform commands from the console, you need to login with a SYSTEM user.
            Email:#{" "}
            Login interrupted.
          OUT
        )
      end
    end
  end

  describe ".wrap" do
    include_context "with stubbed input and output"

    it_behaves_like "working console login" do
      subject { described_class.wrap {} } # rubocop:disable Lint/EmptyBlock
    end

    context "with tty enabled" do
      it_behaves_like "working console login", tty_mode: true do
        subject { described_class.wrap {} } # rubocop:disable Lint/EmptyBlock

        before { allow(input).to receive(:tty?).and_return(true) }
      end
    end

    context "with correct credentials" do
      it "yields" do
        expect { |block| described_class.wrap(&block) }.to yield_with_no_args
      end

      it "sets the current actor correctly" do
        expect(Decidim::Audit.current_actor).to be_a(Decidim::Audit::Actor::SystemUser)

        described_class.wrap do
          expect(Decidim::Audit.current_actor).to eq(admin)
        end

        expect(Decidim::Audit.current_actor).to be_a(Decidim::Audit::Actor::SystemUser)
      end

      context "when the session is already set" do
        it "yields without wrapping the current actor" do
          described_class.wrap do
            expect(Decidim::Audit).not_to receive(:with_actor)

            expect { |block| described_class.wrap(&block) }.to yield_with_no_args
          end
        end
      end
    end

    context "with incorrect email" do
      let(:provided_email) { "unexisting@example.org" }

      it "does not yield" do
        expect { |block| described_class.wrap(&block) }.not_to yield_with_no_args
      end
    end

    context "with incorrect password" do
      let(:provided_password) { "invalid" }

      it "does not yield" do
        expect { |block| described_class.wrap(&block) }.not_to yield_with_no_args
      end
    end
  end

  describe "#login" do
    include_context "with stubbed input and output"

    it_behaves_like "working console login" do
      subject { session.login }
    end

    context "with tty enabled" do
      it_behaves_like "working console login", tty_mode: true do
        subject { session.login }

        before { allow(input).to receive(:tty?).and_return(true) }
      end
    end

    context "with correct credentials" do
      before { session.login }

      it "sets the user" do
        expect(session.user).to eq(admin)
      end
    end

    context "with incorrect email" do
      let(:provided_email) { "unexisting@example.org" }

      before { session.login }

      it "sets the user" do
        expect(session.user).to be_nil
      end
    end

    context "with incorrect password" do
      let(:provided_password) { "invalid" }

      before { session.login }

      it "sets the user" do
        expect(session.user).to be_nil
      end
    end
  end

  describe "#logout" do
    include_context "with stubbed input and output"

    before { session.login }

    it "sets the user as nil" do
      session.logout
      expect(session.user).to be_nil
    end
  end
end
