# frozen_string_literal: true

require "spec_helper"

describe "Decidim::Audit::ControllerAuditUserRead" do
  let(:described_module) { Decidim::Audit::ControllerAuditUserRead }

  describe ".configure" do
    it "yields within the controller class" do
      expect { |b| described_module.configure(&b) }.to yield_control

      spec = self
      mod = described_module
      described_module.configure do
        spec.expect(self).to spec.eq(mod)
      end
    end
  end

  describe "configuration" do
    subject { klass }

    let(:klass) do
      mod = described_module
      Class.new(ApplicationController) { include mod }
    end

    shared_examples "working controller audit user read configuration" do
      describe ".audit_channel" do
        it "gets and sets the channel" do
          expect(subject.audit_channel).to be_nil
          subject.audit_channel("testing")
          expect(subject.audit_channel).to eq("testing")
        end
      end

      describe ".audit_events" do
        it "gets and sets the events" do
          expect(subject.audit_events).to be_nil
          subject.audit_events("index" => "foobar")
          expect(subject.audit_events).to eq(index: :foobar)
        end
      end

      describe ".audit_restrict_actions" do
        it "gets and sets the restricted actions" do
          expect(subject.audit_restrict_actions).to be_nil
          subject.audit_restrict_actions(%w(index show))
          expect(subject.audit_restrict_actions).to contain_exactly(:index, :show)
        end

        it "sets a single action as an array" do
          subject.audit_restrict_actions("index")
          expect(subject.audit_restrict_actions).to be_a(Array)
          expect(subject.audit_restrict_actions).to contain_exactly(:index)
        end
      end

      describe ".audit_restrict_request_methods" do
        it "gets and sets the restricted request methods" do
          expect(subject.audit_restrict_request_methods).to be_nil
          subject.audit_restrict_request_methods(%w(GET POST))
          expect(subject.audit_restrict_request_methods).to contain_exactly(:GET, :POST)
        end

        it "sets a single request method as an array" do
          subject.audit_restrict_actions("GET")
          expect(subject.audit_restrict_actions).to be_a(Array)
          expect(subject.audit_restrict_actions).to contain_exactly(:GET)
        end
      end
    end

    it_behaves_like "working controller audit user read configuration"

    context "when the module is defined for the superclass" do
      subject { Class.new(klass) }

      it_behaves_like "working controller audit user read configuration"
    end
  end

  describe ".audit_controller" do
    it "configures the controller correctly with the defaults" do
      ctrl = Class.new(ApplicationController)
      described_module.audit_controller(ctrl)

      expect(ctrl.audit_channel).to eq("users_admin")
      expect(ctrl.audit_events).to be_nil
      expect(ctrl.audit_restrict_actions).to be_nil
      expect(ctrl.audit_restrict_request_methods).to be_a(Array)
      expect(ctrl.audit_restrict_request_methods).to contain_exactly(:GET)
    end
  end

  describe "around_action hook" do
    let(:organization) { create(:organization) }
    let(:user) { admins[0] }
    let(:admins) { create_list(:user, 10, :admin, :confirmed, organization:) }

    let(:channel) { nil }
    let(:events) { nil }
    let(:actions) { :index }
    let(:request_methods) { :GET }

    controller do
      around_action :wrap_request

      def index
        render plain: current_organization.admins.map(&:id).join(",")
      end

      def show
        render plain: "Show"
      end

      private

      def current_organization
        request.env["decidim.current_organization"]
      end

      def wrap_request
        Decidim::Audit.with_request(request) do
          yield
        end
      end
    end

    before do
      described_module.audit_controller(controller.class, channel:, events:, actions:, request_methods:)

      routes.draw do
        get "index" => "anonymous#index"
        post "index" => "anonymous#index"
        get "show" => "anonymous#show"
      end

      request.env["decidim.current_organization"] = organization
      sign_in user, scope: :user
    end

    context "when the request matches all constraints" do
      it "logs the action and the user read" do
        expect { get :index }.to change(Decidim::Audit::Log, :count).by(2)

        logs = Decidim::Audit::Log.order(:id).last(2)
        expect(log_details(logs[0])).to eq(
          level: "info",
          channel: "users_admin",
          event: "index",
          details: { "controller" => controller.class.name },
          actor: user
        )
        expect(log_details(logs[1])).to match(
          level: "info",
          channel: "decidim_users",
          event: "read_list",
          details: { "ids" => an_instance_of(Array) },
          actor: user
        )
        expect(logs[1].details["ids"]).to match_array(admins.map(&:id))
      end

      context "with different event" do
        let(:events) { { index: :foobar } }

        it "logs the user read action with the correct event" do
          expect { get :index }.to change(Decidim::Audit::Log, :count).by(2)

          log = Decidim::Audit::Log.order(:id).last(2)
          expect(log[0].channel).to eq("users_admin")
          expect(log[0].event).to eq("index")
          expect(log[1].channel).to eq("decidim_users")
          expect(log[1].event).to eq("foobar")
        end
      end
    end

    context "when action does not match" do
      it "does not log anything" do
        expect { get :show }.not_to change(Decidim::Audit::Log, :count)
      end
    end

    context "when the request method does not match" do
      it "does not log anything" do
        expect { post :index }.not_to change(Decidim::Audit::Log, :count)
      end
    end

    def log_details(log)
      [:level, :channel, :event, :details, :actor].index_with { |detail| log.public_send(detail) }
    end
  end
end
