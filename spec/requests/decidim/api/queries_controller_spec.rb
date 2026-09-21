# frozen_string_literal: true

require "spec_helper"

describe Decidim::Api::QueriesController do
  subject { post(api_path, params: { query:, variables:, operationName: operation_name }) }

  let(:url_helpers) { Decidim::Api::Engine.routes.url_helpers }
  let(:api_path) { url_helpers.root_path }
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user, :confirmed, organization:) }

  let(:query) { %(query($locale: String!) { organization { name { translation(locale: $locale) } } }) }
  let(:variables) { { locale: "en" } }
  let(:operation_name) { nil }

  let(:graphql_response) do
    subject
    response.parsed_body
  end

  before do
    host! organization.host
    login_as current_user, scope: :user

    # Ensures that authentication events are not logged during the actual test
    # request.
    get("/", params: { locale: I18n.default_locale })
  end

  it "audits the query with its variables" do
    expect do
      expect(graphql_response["errors"]).to be_nil
    end.to change(Decidim::Audit::Log, :count).by(1)

    log = Decidim::Audit::Log.order(:id).last
    expect(log.channel).to eq("api_query")
    expect(log.level).to eq("info")
    expect(log.event).to eq("execute")
    expect(log.message).to eq(query)
    expect(log.details).to match("variables" => variables.stringify_keys)
    expect(log.actor).to eq(current_user)
  end

  context "with operation name" do
    let(:query) { %(query OrganizationName($locale: String!) { organization { name { translation(locale: $locale) } } }) }
    let(:operation_name) { "OrganizationName" }

    it "adds the operation name to the logs" do
      expect do
        expect(graphql_response["errors"]).to be_nil
      end.to change(Decidim::Audit::Log, :count).by(1)

      log = Decidim::Audit::Log.order(:id).last
      expect(log.details).to match(
        "variables" => variables.stringify_keys,
        "operation_name" => operation_name
      )
    end
  end

  context "with a parse error" do
    let(:query) { %({ organization { name { translation(locale: "en) } } }) }

    it "audits the query and the error" do
      expect do
        expect(graphql_response["errors"]).to be_a(Array)
      end.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      expect(logs.pluck(:channel).uniq).to eq(["api_query"])
      expect(logs[0].event).to eq("execute")
      expect(logs[1].level).to eq("error")
      expect(logs[1].event).to eq("error")
      expect(logs[1].message).to eq("parse_error")
      expect(logs[1].details["errors"]).to eq(["GraphQL::ParseError"])
    end
  end

  context "with a validation error" do
    let(:query) { %({ organization { name } }) }

    it "audits the query and the error" do
      expect do
        expect(graphql_response["errors"]).to be_a(Array)
      end.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      expect(logs.pluck(:channel).uniq).to eq(["api_query"])
      expect(logs[0].event).to eq("execute")
      expect(logs[1].level).to eq("error")
      expect(logs[1].event).to eq("error")
      expect(logs[1].message).to eq("validation_error")
      expect(logs[1].details["errors"]).to eq(["GraphQL::StaticValidation::FieldsHaveAppropriateSelectionsError"])
    end
  end

  context "with an execution error" do
    let(:query) { %({ users(order: { id: "UNKNOWN" }) { name } }) }

    it "audits the query and the error" do
      expect do
        expect(graphql_response["errors"]).to be_a(Array)
      end.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      expect(logs.pluck(:channel).uniq).to eq(["api_query"])
      expect(logs[0].event).to eq("execute")
      expect(logs[1].level).to eq("error")
      expect(logs[1].event).to eq("error")
      expect(logs[1].message).to eq("execution_error")
      expect(logs[1].details["errors"]).to eq(["GraphQL::ExecutionError"])
    end
  end

  context "when querying a single user" do
    let(:query) { %(query($id: ID) { user(id: $id) { id name } }) }
    let(:variables) { { id: target_user.id.to_s } }
    let!(:target_user) { create(:user, :confirmed, organization:) }

    it "audits the user record read" do
      expect do
        expect(graphql_response["errors"]).to be_nil
      end.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      expect(logs[0].channel).to eq("api_query")
      expect(logs[1].channel).to eq("decidim_users")
      expect(logs[1].level).to eq("info")
      expect(logs[1].event).to eq("api")
      expect(logs[1].details).to match("ids" => [target_user.id])
    end
  end

  context "when querying multiple users" do
    let(:query) { %({ users { id name } }) }
    let!(:target_users) { create_list(:user, 10, :confirmed, organization:) }

    it "audits the user record reads" do
      expect do
        expect(graphql_response["errors"]).to be_nil
      end.to change(Decidim::Audit::Log, :count).by(2)

      logs = Decidim::Audit::Log.order(:id).last(2)
      expect(logs[0].channel).to eq("api_query")
      expect(logs[1].channel).to eq("decidim_users")
      expect(logs[1].level).to eq("info")
      expect(logs[1].event).to eq("api")
      expect(logs[1].details).to match("ids" => an_instance_of(Array))
      expect(logs[1].details["ids"]).to match_array([current_user.id] + target_users.map(&:id))
    end
  end
end
