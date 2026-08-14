# frozen_string_literal: true

shared_examples "request details logging" do |channel:, event:|
  let(:expected_method) { "POST" }
  let(:expected_path) { "/users/sign_in" }

  it "logs the correct request details" do
    log = Decidim::Audit::Log.find_by(channel:, event:)
    expect(log.request_details.except("request_id", "request_uuid")).to match(
      "request_method" => expected_method,
      "request_path" => expected_path,
      "ip" => request_headers["REMOTE_ADDR"],
      "remote_ip" => request_headers["HTTP_CLIENT_IP"],
      "user_agent" => request_headers["HTTP_USER_AGENT"],
      "sec_ch_ua" => request_headers["HTTP_SEC_CH_UA"],
      "sec_ch_ua_mobile" => request_headers["HTTP_SEC_CH_UA_MOBILE"],
      "sec_ch_ua_platform" => request_headers["HTTP_SEC_CH_UA_PLATFORM"]
    )
  end
end
