# frozen_string_literal: true

require "spec_helper"

describe "Console" do
  it_behaves_like "console session" do
    subject do
      output = ""
      Open3.popen2("bundle exec rails console -e test") do |stdin, stdout, _wait_thr|
        sleep 1
        stdin.puts(provided_email)
        stdin.puts(provided_password)
        stdin.close

        output = stdout.read
        stdout.close
      end

      output
    end
  end

  context "when interrupting" do
    include ActiveSupport::Testing::Stream

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

    it "interrupts cleanly" do
      lines = []
      Open3.popen2("bundle exec rails console -e test") do |stdin, stdout, wait_thr|
        sleep 1
        Process.kill("INT", wait_thr.pid)
        sleep 1
        stdin.close

        lines = stdout.readlines
        stdout.close
      end

      expect(lines[-3..].join.strip).to eq(
        <<~OUT.strip
          To perform commands from the console, you need to login with a SYSTEM user.
          Email:#{" "}
          Login interrupted.
        OUT
      )
    end
  end
end
