# frozen_string_literal: true

require "decidim/components/namer"
require "decidim/core/test/factories"

FactoryBot.define do
  factory :audit_log, class: "Decidim::Audit::Log" do
    transient do
      skip_injection { false }
    end
    organization { build(:organization, skip_injection:) }
    level { "info" }
    channel { "testing" }
    event { "test" }

    trait :with_message do
      message { generate(:title) }
    end

    trait :with_details do
      details { { foo: "foo", bar: "bar" } }
    end

    trait :with_user_actor do
      actor { create(:user, :confirmed, organization:).to_gid }
    end

    trait :with_visitor_actor do
      actor do
        Decidim::Audit::Actor::Visitor.new(
          "S",
          SecureRandom.uuid,
          Faker::Internet.public_ip_v4_address
        ).to_gid
      end
    end

    trait :with_system_actor do
      actor do
        Decidim::Audit::Actor::SystemUser.new(
          rand(1000..1100),
          rand(2000..2100),
          Faker::Internet.username,
          Faker::Name.name
        ).to_gid
      end
    end

    trait :with_request do
      transient do
        browser_vendor { [:chrome, :firefox, :opera, :safari].sample }
      end

      sec_ch_ua_strings = {
        chrome: %(" Not A;Brand";v="99", "Chromium";v="96", "Google Chrome";v="96"),
        opera: %("Opera";v="81", " Not;A Brand";v="99", "Chromium";v="95")
      }

      request_details do
        {
          request_id: SecureRandom.uuid,
          request_method: "POST",
          request_path: "/testing",
          ip: Faker::Internet.private_ip_v4_address,
          remote_ip: Faker::Internet.public_ip_v4_address,
          user_agent: Faker::Internet.user_agent(vendor: browser_vendor),
          sec_ch_ua: sec_ch_ua_strings[browser_vendor],
          sec_ch_ua_mobile: sec_ch_ua_strings.has_key?(browser_vendor) ? "?1" : nil,
          sec_ch_ua_platform: sec_ch_ua_strings.has_key?(browser_vendor) ? %("Linux") : nil
        }
      end
    end

    trait :with_resource do
      resource do
        create(
          :dummy_resource,
          component: create(
            :component,
            participatory_space: create(:participatory_process, organization:)
          )
        )
      end
    end

    trait :with_changed_resource do
      with_resource
      resource_changes do
        {
          "title" => [
            generate_localized_title(:dummy_resource_title, skip_injection:),
            resource.title
          ]
        }
      end
    end

    trait :with_full_details do
      with_message
      with_details
      with_user_actor
      with_request
      with_changed_resource
    end
  end
end
