# frozen_string_literal: true

require "spec_helper"

describe Decidim::Audit::Logger::HashFormatter do
  subject(:instance) { described_class.new(hash) }

  let(:hash) do
    {
      foo: ["bar", { foo: "foo", bar: "bar" }],
      bar: {
        foo: {
          foo: "foo",
          bar: "bar"
        },
        bar: "bar"
      }
    }
  end

  let(:sorted_hash) do
    {
      bar: {
        bar: "bar",
        foo: {
          bar: "bar",
          foo: "foo"
        }
      },
      foo: ["bar", { bar: "bar", foo: "foo" }]
    }
  end

  describe "#format" do
    subject { instance.format }

    it { is_expected.to eq(ActiveSupport::OrderedHash[sorted_hash].to_json) }
  end
end
