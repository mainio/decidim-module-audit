# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Actor::SystemUser do
  subject(:instance) { described_class.new(uid, gid, name, gecos) }

  let(:uid) { 1001 }
  let(:gid) { 2000 }
  let(:name) { "johndoe" }
  let(:gecos) { "John Doe" }

  describe ".fetch" do
    subject { described_class.fetch }

    let(:dummy_pwuid) { Etc::Passwd.new(name:, uid:, gid:, gecos:) }

    before do
      allow(Etc).to receive(:getpwuid).and_return(dummy_pwuid)
    end

    it "creates a new instance" do
      expect(subject).to be_a(described_class)
      expect(subject.uid).to eq(uid)
      expect(subject.gid).to eq(gid)
      expect(subject.gecos).to eq(gecos)
    end
  end

  describe ".find" do
    subject { described_class.find(id, params) }

    let(:params) { { gecos: } }

    context "with valid details" do
      let(:id) { [uid, gid, name] }

      it { is_expected.to be_a(described_class) }

      it "returns an instance with correct details" do
        expect(subject.uid).to eq(uid)
        expect(subject.gid).to eq(gid)
        expect(subject.name).to eq(name)
        expect(subject.gecos).to eq(gecos)
      end

      context "without params" do
        subject { described_class.find(id) }

        it { is_expected.to be_a(described_class) }

        it "returns an instance with correct details" do
          expect(subject.uid).to eq(uid)
          expect(subject.gid).to eq(gid)
          expect(subject.name).to eq(name)
          expect(subject.gecos).to be_nil
        end
      end
    end

    context "with id being a non-array" do
      let(:id) { "xyz123" }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with incorrectly formed array" do
      let(:id) { [uid, gid, name, "foobar"] }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }

      context "without the name part" do
        let(:id) { [uid, gid] }

        it { expect { subject }.to raise_error(described_class::InvalidIdError) }
      end

      context "without the gid and name part" do
        let(:id) { [uid] }

        it { expect { subject }.to raise_error(described_class::InvalidIdError) }
      end
    end

    context "with an nil type as uid" do
      let(:id) { [nil, gid, name] }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with a nil type as gid" do
      let(:id) { [uid, nil, name] }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with a nil type as name" do
      let(:id) { [uid, gid, nil] }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with empty uid" do
      let(:id) { ["", gid, name] }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with empty gid" do
      let(:id) { [uid, "", name] }

      it { expect { subject }.to raise_error(described_class::InvalidIdError) }
    end

    context "with empty name" do
      let(:id) { [uid, gid, ""] }

      it { is_expected.to be_a(described_class) }

      it "returns the blank name" do
        expect(subject.name).to eq("")
      end
    end
  end

  describe "#id" do
    subject { instance.id }

    it { is_expected.to eq([uid, gid, name]) }
  end

  [:to_global_id, :to_gid].each do |method|
    describe "##{method}" do
      subject { instance.to_global_id }

      it { is_expected.to be_a(GlobalID) }

      it "returns a valid ID" do
        expect(subject.to_s).to eq("gid://decidim-audit-module/#{described_class.name}/#{uid}/#{gid}/#{name}?gecos=#{CGI.escape(gecos)}")
      end

      it "can be used to find a record" do
        record = GlobalID.find(subject.to_s)
        expect(record).to be_a(described_class)
        expect(record.uid).to eq(uid)
        expect(record.gid).to eq(gid)
        expect(record.name).to eq(name)
        expect(record.gecos).to eq(gecos)
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
        expect(record.uid).to eq(uid)
        expect(record.gid).to eq(gid)
        expect(record.name).to eq(name)
        expect(record.gecos).to eq(gecos)
      end
    end
  end
end
