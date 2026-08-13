# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit do
  describe ".with_request" do
    let(:request) { double }

    it "sets the current request during yield" do
      expect(described_class.current_request).to be_nil
      described_class.with_request(request) do
        expect(described_class.current_request).to be_a(Decidim::Audit::Request)
        expect(described_class.current_request.send(:req)).to eq(request)
      end
      expect(described_class.current_request).to be_nil
    end

    it "raises an error if the request is already set" do
      described_class.with_request(request) do
        expect { described_class.with_request(request) }.to raise_error(Decidim::Audit::RequestDefinedError)
      end
    end
  end

  describe ".with_actor" do
    let(:actor) { double }

    it "sets the current actor during yield" do
      expect(described_class.current_actor).to be_a(Decidim::Audit::Actor::SystemUser)
      described_class.with_actor(actor) do
        expect(described_class.current_actor).to eq(actor)
      end
      expect(described_class.current_actor).to be_a(Decidim::Audit::Actor::SystemUser)
    end

    it "raises an error if the actor is already set" do
      described_class.with_actor(actor) do
        expect { described_class.with_actor(actor) }.to raise_error(Decidim::Audit::ActorDefinedError)
      end
    end
  end

  describe ".current_actor" do
    subject { described_class.current_actor }

    it "returns system user by default" do
      expect(subject).to be_a(Decidim::Audit::Actor::SystemUser)
    end

    context "when the current actor is defined" do
      let(:actor) { double }

      it "returns the current actor" do
        described_class.with_actor(actor) do
          expect(subject).to eq(actor)
        end
      end

      context "and the current request is defined" do
        let(:request) { double }

        it "returns the current actor" do
          described_class.with_request(request) do
            described_class.with_actor(actor) do
              expect(subject).to eq(actor)
            end
          end
        end
      end
    end

    context "when the current request is defined" do
      let(:request) { double(env: request_env) }
      let(:request_env) { { "warden" => warden } }
      let(:warden) { double }
      let(:user) { build(:user, :confirmed) }

      before do
        allow(warden).to receive(:user).with(scope: :user).and_return(user)
      end

      it "returns the actor through the request" do
        described_class.with_request(request) do
          expect(subject).to eq(user)
        end
      end

      context "without warden" do
        let(:request) { double(env: {}, session: double(id: "xyz123"), remote_ip: "1.2.3.4") }

        it "returns the actor through the request" do
          described_class.with_request(request) do
            expect(subject).to be_a(Decidim::Audit::Actor::Visitor)
          end
        end
      end
    end
  end

  describe ".log" do
    subject do
      described_class.log(
        channel:,
        event:,
        message:,
        organization:,
        level:,
        details:,
        actor:,
        request_details:,
        resource:,
        resource_changes:
      )
    end

    let(:channel) { "testing" }
    let(:event) { "test" }
    let(:message) { "msg" }
    let(:organization) { create(:organization) }
    let(:level) { :info }
    let(:details) { { foo: "bar" } }
    let(:actor) { Decidim::Audit::Actor::Visitor.new("S", "xyz123", "1.2.3.4") }
    let(:request_details) { { ip: "1.2.3.4" } }
    let!(:resource) { create(:user, :confirmed, organization:) }
    let(:resource_changes) { { name: ["Old Name", resource.name] } }

    it "creates a new log record with correct details" do
      expect { subject }.to change(Decidim::Audit::Log, :count).by(1)
      expect(subject).to be_a(Decidim::Audit::Log)
      expect(subject.channel).to eq(channel)
      expect(subject.event).to eq(event)
      expect(subject.message).to eq(message)
      expect(subject.organization).to eq(organization)
      expect(subject.level).to eq(level.to_s)
      expect(subject.details).to match(details.stringify_keys)
      expect(subject.actor).to be_a(Decidim::Audit::Actor::Visitor)
      expect(subject.actor_type).to eq("visitor")
      expect(subject.actor_roles).to be_nil
      expect(subject.request_details).to match(request_details.stringify_keys)
      expect(subject.resource).to eq(resource)
      expect(subject.resource_changes).to eq(resource_changes.stringify_keys)
    end

    context "with only channel and event" do
      subject { described_class.log(channel:, event:) }

      it "creates a new log record with correct details" do
        expect { subject }.to change(Decidim::Audit::Log, :count).by(1)
        expect(subject).to be_a(Decidim::Audit::Log)
        expect(subject.channel).to eq(channel)
        expect(subject.event).to eq(event)
        expect(subject.message).to be_nil
        expect(subject.organization).to be_nil
        expect(subject.level).to eq("info")
        expect(subject.details).to be_nil
        expect(subject.actor).to be_a(Decidim::Audit::Actor::SystemUser)
        expect(subject.actor_type).to eq("system_user")
        expect(subject.actor_roles).to be_nil
        expect(subject.request_details).to be_nil
        expect(subject.resource).to be_nil
        expect(subject.resource_changes).to be_nil
      end

      context "with current request" do
        let(:request) do
          double(
            env: request_env,
            request_id:,
            request_method:,
            path: request_path,
            ip:,
            remote_ip:
          )
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
        let(:request_env) { { "warden" => warden, "decidim.current_organization" => organization } }
        let(:warden) { double }
        let(:current_user) { create(:user, :confirmed, organization:) }

        before do
          allow(request).to receive(:get_header) { |key| request_headers[key] }
          allow(warden).to receive(:user).with(scope: :user).and_return(current_user)

          described_class.with_request(request) { subject }
        end

        it "fetches the organization from the request automatically" do
          expect(subject.organization).to eq(organization)
        end

        it "fetches the actor from the request automatically" do
          expect(subject.actor).to eq(current_user)
          expect(subject.actor_type).to eq("organization_user")
          expect(subject.actor_roles).to be_nil
        end

        it "fetches the request details from the request automatically" do
          expect(subject.request_details).to match(
            "request_id" => request_id,
            "request_method" => request_method,
            "request_path" => request_path,
            "ip" => ip,
            "remote_ip" => remote_ip,
            "user_agent" => request_headers["HTTP_USER_AGENT"],
            "sec_ch_ua" => request_headers["HTTP_SEC_CH_UA"],
            "sec_ch_ua_mobile" => request_headers["HTTP_SEC_CH_UA_MOBILE"],
            "sec_ch_ua_platform" => request_headers["HTTP_SEC_CH_UA_PLATFORM"]
          )
        end
      end

      context "with current actor" do
        before do
          try(:prepare_test)
          described_class.with_actor(current_actor) { subject }
        end

        context "with organization user" do
          let(:current_actor) { create(:user, :confirmed, organization:) }

          it "sets the actor details automatically" do
            expect(subject.actor).to eq(current_actor)
            expect(subject.actor_type).to eq("organization_user")
            expect(subject.actor_roles).to be_nil
          end

          context "with account roles and participatory space roles" do
            let(:current_actor) { create(:user, :confirmed, :user_manager, organization:) }
            let(:space1) { create(:assembly, :published, organization:) }
            let(:space2) { create(:participatory_process, :published, organization:) }
            let(:role1) { create(:assembly_user_role, assembly: space1, user: current_actor, role: "collaborator") }
            let(:role2) { create(:participatory_process_user_role, participatory_process: space2, user: current_actor, role: "moderator") }

            def prepare_test
              role1 && role2
            end

            it "sets the actor details automatically" do
              expect(subject.actor).to eq(current_actor)
              expect(subject.actor_type).to eq("organization_user")
              expect(subject.actor_roles).to eq(["user_manager", "assembly_#{space1.id}_collaborator", "process_#{space2.id}_moderator"])
            end
          end
        end

        context "with organization admin" do
          let(:current_actor) { create(:user, :confirmed, :admin, organization:) }

          it "sets the actor details automatically" do
            expect(subject.actor).to eq(current_actor)
            expect(subject.actor_type).to eq("organization_admin")
            expect(subject.actor_roles).to be_nil
          end
        end

        context "with system user" do
          let(:current_actor) { build(:audit_system_user) }

          it "sets the actor details automatically" do
            expect(subject.actor).to eq(current_actor)
            expect(subject.actor_type).to eq("system_user")
            expect(subject.actor_roles).to be_nil
          end
        end

        context "with visitor" do
          let(:current_actor) { build(:audit_visitor) }

          it "sets the actor details automatically" do
            expect(subject.actor).to eq(current_actor)
            expect(subject.actor_type).to eq("visitor")
            expect(subject.actor_roles).to be_nil
          end
        end
      end
    end
  end
end
