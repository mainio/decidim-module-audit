# frozen_string_literal: true

module Decidim
  module Audit
    module Middleware
      # A middleware that stores information about the request for audit logging
      # purposes. This information can be used with the actual audit logging
      # records, such as authentication success or failure events.
      class AuditContext
        # Initializes the Rack Middleware.
        #
        # app - The Rack application
        def initialize(app)
          @app = app
        end

        # Main entry point for a Rack Middleware.
        #
        # env - A Hash.
        def call(env)
          @req = ActionDispatch::Request.new(env)
          Decidim::Audit.with_request(req) do
            @app.call(env)
          end
        end

        private

        attr_reader :req
      end
    end
  end
end
