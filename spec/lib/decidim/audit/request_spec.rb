# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Request do
  subject(:instance) { described_class.new(rack_request) }

  let(:rack_request) do
    double(
      request_id:,
      requestid: request_id,
      request_method:,
      path: request_path,
      ip:,
      remote_ip:,
      session:,
      env: request_env
    )
  end
  let(:request_env) do
    {
      "warden" => warden,
      "decidim.current_organization" => organization
    }
  end
  let(:request_id) { "123456" }
  let(:request_method) { "POST" }
  let(:request_path) { "/path" }
  let(:ip) { "10.0.0.1" }
  let(:remote_ip) { "1.2.3.4" }
  let(:request_headers) do
    {
      "HTTP_USER_AGENT" => "RSpec testing",
      "HTTP_SEC_CH_UA" => %("Not;A=Brand";v="1", "SomeBrand";v="2"),
      "HTTP_SEC_CH_UA_MOBILE" => "?0",
      "HTTP_SEC_CH_UA_PLATFORM" => %("Linux")
    }
  end
  let(:session) { double(id: session_id) }
  let(:session_id) { "xyz123" }
  let(:warden) { double }
  let(:organization) { build(:organization) }
  let(:user) { build(:user, :confirmed, organization:) }

  before do
    allow(rack_request).to receive(:get_header) do |key|
      request_headers[key]
    end
    allow(warden).to receive(:user).with(scope: :user).and_return(user)
  end

  describe "#organization" do
    subject { instance.organization }

    it { is_expected.to eq(organization) }
  end

  describe "#actor" do
    subject { instance.actor }

    context "with user" do
      it { is_expected.to eq(user) }
    end

    context "without user" do
      let(:user) { nil }

      it { is_expected.to be_a(Decidim::Audit::Actor::Visitor) }

      it "sets the correct details for the visitor" do
        expect(subject.type).to eq("S")
        expect(subject.identifier).to eq(session_id)
        expect(subject.ip).to eq(remote_ip)
      end

      context "without session" do
        let(:session) { nil }

        it "sets the correct details for the visitor" do
          expect(subject.type).to eq("R")
          expect(subject.identifier).to eq(request_id)
          expect(subject.ip).to eq(remote_ip)
        end
      end
    end

    context "with memoized visitor and logged in user" do
      let(:user) { nil }

      it "returns the user when set" do
        expect(instance.actor).to be_a(Decidim::Audit::Actor::Visitor)

        logged_in_user = build(:user, :confirmed, organization:)
        allow(warden).to receive(:user).with(scope: :user).and_return(logged_in_user)
        expect(instance.actor).to eq(logged_in_user)
      end
    end

    context "without warden" do
      let(:request_env) { {} }

      it { is_expected.to be_a(Decidim::Audit::Actor::Visitor) }
    end
  end

  describe "#visitor" do
    subject { instance.visitor }

    it { is_expected.to be_a(Decidim::Audit::Actor::Visitor) }

    it "sets the correct details for the visitor" do
      expect(subject.type).to eq("S")
      expect(subject.identifier).to eq(session_id)
      expect(subject.ip).to eq(remote_ip)
    end
  end

  describe "#details" do
    subject { instance.details }

    it "returns the correct details" do
      expect(subject).to match(
        request_id:,
        request_method:,
        request_path:,
        ip:,
        remote_ip:,
        user_agent: request_headers["HTTP_USER_AGENT"],
        sec_ch_ua: request_headers["HTTP_SEC_CH_UA"],
        sec_ch_ua_mobile: request_headers["HTTP_SEC_CH_UA_MOBILE"],
        sec_ch_ua_platform: request_headers["HTTP_SEC_CH_UA_PLATFORM"]
      )
    end
  end
end
