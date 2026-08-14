# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Actor::Visitor do
  subject(:instance) { described_class.new(type, identifier, uuid, ip) }

  let(:type) { "S" }
  let(:identifier) { "xyz123" }
  let(:uuid) { nil }
  let(:ip) { "1.2.3.4" }

  describe ".from_request" do
    subject { described_class.from_request(request) }

    let(:request) { double(session:, requestid:, uuid: request_uuid, remote_ip:) }
    let(:session) { nil }
    let(:sessionid) { "xyz123" }
    let(:requestid) { "123456" }
    let(:request_uuid) { "00000000-1111-2222-3333-44444444444" }
    let(:remote_ip) { "1.2.3.4" }

    context "with session" do
      let(:session) { double(id: sessionid) }
      let(:sessionid) { "xyz123" }

      it { is_expected.to be_a(described_class) }

      it "returns an instance with correct details" do
        expect(subject.type).to eq("S")
        expect(subject.identifier).to eq(sessionid)
        expect(subject.ip).to eq(remote_ip)
      end
    end

    context "without session" do
      it { is_expected.to be_a(described_class) }

      it "returns an instance with correct details" do
        expect(subject.type).to eq("R")
        expect(subject.identifier).to eq(requestid)
        expect(subject.uuid).to eq(request_uuid)
        expect(subject.ip).to eq(remote_ip)
      end
    end
  end

  describe ".find" do
    subject { described_class.find(id, params) }

    let(:params) { {} }

    context "with session details" do
      let(:id) { ["S", sessionid] }
      let(:sessionid) { "xyz123" }
      let(:params) { { ip: "1.2.3.4" } }

      it { is_expected.to be_a(described_class) }

      it "returns an instance with correct details" do
        expect(subject.type).to eq("S")
        expect(subject.identifier).to eq(sessionid)
        expect(subject.uuid).to be_nil
        expect(subject.ip).to eq(params[:ip])
      end

      context "without params" do
        subject { described_class.find(id) }

        it { is_expected.to be_a(described_class) }

        it "returns an instance with correct details" do
          expect(subject.type).to eq("S")
          expect(subject.identifier).to eq(sessionid)
          expect(subject.uuid).to be_nil
          expect(subject.ip).to be_nil
        end
      end

      context "without uuid" do
        let(:id) { ["S", sessionid] }

        it "returns an instance with correct details" do
          expect(subject.type).to eq("S")
          expect(subject.identifier).to eq(sessionid)
          expect(subject.uuid).to be_nil
          expect(subject.ip).to eq(params[:ip])
        end
      end
    end

    context "with request details" do
      let(:id) { ["R", requestid, request_uuid] }
      let(:requestid) { "123456" }
      let(:request_uuid) { "00000000-1111-2222-3333-44444444444" }
      let(:params) { { ip: "1.2.3.4" } }

      it { is_expected.to be_a(described_class) }

      it "returns an instance with correct details" do
        expect(subject.type).to eq("R")
        expect(subject.identifier).to eq(requestid)
        expect(subject.uuid).to eq(request_uuid)
        expect(subject.ip).to eq(params[:ip])
      end

      context "without params" do
        subject { described_class.find(id) }

        it { is_expected.to be_a(described_class) }

        it "returns an instance with correct details" do
          expect(subject.type).to eq("R")
          expect(subject.identifier).to eq(requestid)
          expect(subject.uuid).to eq(request_uuid)
          expect(subject.ip).to be_nil
        end
      end

      context "without uuid" do
        let(:id) { ["R", requestid] }

        it "returns an instance with correct details" do
          expect(subject.type).to eq("R")
          expect(subject.identifier).to eq(requestid)
          expect(subject.uuid).to be_nil
          expect(subject.ip).to eq(params[:ip])
        end
      end
    end

    context "with id being a non-array" do
      let(:id) { "xyz123" }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with incorrectly formed array" do
      let(:id) { %w(S xyz123 uuid foobar) }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }

      context "without the ID part" do
        let(:id) { %w(S) }

        it { expect { subject }.to raise_error(described_class::InvalidIdError) }
      end
    end

    context "with an integer type" do
      let(:id) { [123, "xyz123", "uuid"] }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with a nil type" do
      let(:id) { [nil, "xyz123", "uuid"] }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with incorrect type" do
      let(:id) { %w(X xyz uuid) }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with empty identifier" do
      let(:id) { ["S", ""] }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with nil identifier" do
      let(:id) { ["S", nil] }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end
  end

  describe "#id" do
    subject { instance.id }

    it { is_expected.to eq([type, identifier]) }
  end

  [:to_global_id, :to_gid].each do |method|
    describe "##{method}" do
      subject { instance.to_global_id }

      it { is_expected.to be_a(GlobalID) }

      it "returns a valid ID" do
        expect(subject.to_s).to eq("gid://decidim-audit-module/#{described_class.name}/#{type}/#{identifier}?ip=#{ip}")
      end

      it "can be used to find a record" do
        record = GlobalID.find(subject.to_s)
        expect(record).to be_a(described_class)
        expect(record.type).to eq(type)
        expect(record.identifier).to eq(identifier)
        expect(record.ip).to eq(ip)
      end

      context "with request type" do
        let(:type) { "R" }
        let(:uuid) { "00000000-1111-2222-3333-44444444444" }

        it "returns a valid ID" do
          expect(subject.to_s).to eq("gid://decidim-audit-module/#{described_class.name}/#{type}/#{identifier}/#{uuid}?ip=#{ip}")
        end

        it "can be used to find a record" do
          record = GlobalID.find(subject.to_s)
          expect(record).to be_a(described_class)
          expect(record.type).to eq(type)
          expect(record.identifier).to eq(identifier)
          expect(record.uuid).to eq(uuid)
          expect(record.ip).to eq(ip)
        end
      end
    end
  end

  [:to_signed_global_id, :to_sgid].each do |method|
    describe "##{method}" do
      subject { instance.to_signed_global_id }

      let(:verifier) { Rails.application.config.global_id.verifier }

      it { is_expected.to be_a(SignedGlobalID) }

      it "returns a valid ID" do
        expect(subject.to_s).to eq(verifier.generate(subject.uri.to_s, purpose: subject.purpose, expires_at: subject.expires_at))
      end

      it "can be used to find a record" do
        record = SignedGlobalID.find(subject.to_s)
        expect(record).to be_a(described_class)
        expect(record.type).to eq(type)
        expect(record.identifier).to eq(identifier)
        expect(record.ip).to eq(ip)
      end

      context "with request type" do
        let(:type) { "R" }
        let(:uuid) { "00000000-1111-2222-3333-44444444444" }

        it "returns a valid ID" do
          expect(subject.to_s).to eq(verifier.generate(subject.uri.to_s, purpose: subject.purpose, expires_at: subject.expires_at))
        end

        it "can be used to find a record" do
          record = SignedGlobalID.find(subject.to_s)
          expect(record).to be_a(described_class)
          expect(record.type).to eq(type)
          expect(record.identifier).to eq(identifier)
          expect(record.uuid).to eq(uuid)
          expect(record.ip).to eq(ip)
        end
      end
    end
  end
end
