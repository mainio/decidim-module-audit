# frozen_string_literal: true

require "active_support/testing/stream"

shared_examples "console session" do
  include ActiveSupport::Testing::Stream

  # With transactional specs, the user would not be persisted over to the
  # console session.
  include_context "with concurrency"

  let!(:admin) { create(:admin, email:, password:, password_confirmation: password) }
  let(:email) { "system@example.org" }
  let(:provided_email) { email }
  let(:password) { "decidim123456789" }
  let(:provided_password) { password }

  around do |example|
    original_pwd = Dir.pwd

    begin
      Dir.chdir("spec/decidim_dummy_app")

      # Silence Spring messages and Rails DB query logger.
      capture("stderr") do
        example.run
      end
    ensure
      Dir.chdir(original_pwd)
    end
  end

  context "with correct credentials" do
    it "starts the process with a successful login" do
      expect(subject).not_to include("Invalid email or password.")
    end
  end

  context "with incorrect email" do
    let(:provided_email) { "unexisting@example.org" }

    it "does not start the process" do
      expect(subject).to include("Invalid email or password.")
    end
  end

  context "with incorrect password" do
    let(:provided_password) { "invalid" }

    it "does not start the process" do
      expect(subject).to include("Invalid email or password.")
    end
  end
end
