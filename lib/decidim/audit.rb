# frozen_string_literal: true

require "decidim/audit/engine"
require "decidim/audit/warden"

module Decidim
  # This namespace holds the logic of the `Audit` functionality.
  # rubocop:disable Metrics/ParameterLists
  module Audit
    autoload :Actor, "decidim/audit/actor"
    autoload :Request, "decidim/audit/request"
    autoload :Logger, "decidim/audit/logger"
    autoload :Resolver, "decidim/audit/resolver"

    class << self
      attr_reader :current_request

      def with_request(req)
        raise RequestDefinedError, "Request has been already defined." if instance_variable_defined?(:@current_request)

        @current_request = Request.new(req)
        yield
      ensure
        remove_instance_variable(:@current_request) if instance_variable_defined?(:@current_request)
      end

      def with_actor(actor)
        raise ActorDefinedError, "Actor has been already defined." if instance_variable_defined?(:@current_actor)

        @current_actor = actor
        yield
      ensure
        remove_instance_variable(:@current_actor) if instance_variable_defined?(:@current_actor)
      end

      def current_actor
        @current_actor || current_request&.actor || Decidim::Audit::Actor::SystemUser.fetch
      end

      def log(
        channel:,
        event:,
        message: nil,
        organization: current_request&.organization,
        level: :info,
        details: nil,
        actor: current_actor,
        request_details: current_request&.details,
        resource: nil,
        resource_id: nil,
        resource_type: nil,
        resource_changes: nil
      )
        actor_details = Decidim::Audit::Resolver::ActorDetails.for(actor)

        resource_attrs =
          if resource_id && resource_type
            { resource_id:, resource_type: }
          else
            { resource: }
          end

        Decidim::Audit::Log.create!(
          organization:,
          level:,
          channel:,
          event:,
          message:,
          details:,
          actor: actor&.to_gid&.to_s,
          actor_type: actor_details.type,
          actor_roles: actor_details.roles,
          request_details:,
          **resource_attrs,
          resource_changes:
        )
      end
    end

    class ActorDefinedError < StandardError; end

    class RequestDefinedError < StandardError; end

    mattr_accessor :retention_period_days, default: Decidim::Env.new("DECIDIM_AUDIT_RETENTION_PERIOD_DAYS", "365").to_i
  end
  # rubocop:enable Metrics/ParameterLists
end
