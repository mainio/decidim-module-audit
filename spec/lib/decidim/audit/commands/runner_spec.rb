# frozen_string_literal: true

require "spec_helper"

describe "Console" do
  it_behaves_like "console session" do
    subject do
      output = ""
      Open3.popen2(%(bundle exec rails runner -e test 'puts Decidim::System::Admin.count')) do |stdin, stdout, _wait_thr|
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
end
