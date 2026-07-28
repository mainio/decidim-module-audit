# frozen_string_literal: true

require "omniauth"

module OmniAuth
  module Strategies
    class Test
      include OmniAuth::Strategy

      uid do
        request.params["email"]
      end

      info do
        {
          name: request.params["name"],
          nickname: request.params["nickname"],
          email: request.params["email"]
        }
      end

      def request_phase
        form = OmniAuth::Form.new(:title => "User Info", :url => callback_path, :method => "get")
        form.button "Sign In"
        form.to_response
      end

      def callback_phase
        raise CallbackError.new(request.params["fail_key"], request.params["fail_message"]) if request.params["fail"] == "1"

        super
      rescue CallbackError => e
        fail!(e.key, e)
      end

      class CallbackError < StandardError
        attr_reader :key

        def initialize(key, message = nil)
          @key = key.to_s
          super(message)
        end
      end
    end
  end
end

module Decidim
  module Audit
    module Test
      # This is a engine for the test environment to add specific configurations
      # to the application for testing purposes.
      class Railtie < ::Rails::Engine
        isolate_namespace Decidim::Audit::Test

        paths["db/migrate"] = nil
        paths["lib/tasks"] = nil

        initializer "decidim_audit_test.omniauth" do
          Rails.application.config.middleware.use OmniAuth::Builder do
            provider(
              :test,
              fields: [:name, :nickname, :email]
            )
          end
        end
      end
    end
  end
end
