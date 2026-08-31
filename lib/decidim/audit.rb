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
      def current_request
        ConcurrentStore.current_request.value
      end

      def with_request(req)
        raise RequestDefinedError, "Request has been already defined." if current_request

        ConcurrentStore.current_request.bind(Request.new(req)) { yield }
      end

      def with_actor(actor)
        raise ActorDefinedError, "Actor has been already defined." if ConcurrentStore.current_actor.value

        ConcurrentStore.current_actor.bind(actor) { yield }
      end

      def current_actor
        ConcurrentStore.current_actor.value || current_request&.actor || Decidim::Audit::Actor::SystemUser.fetch
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

    module ConcurrentStore
      class << self
        def current_request
          @current_request ||= Concurrent::LockLocalVar.new
        end

        def current_actor
          @current_actor ||= Concurrent::LockLocalVar.new
        end
      end
    end

    mattr_accessor :retention_period_days, default: Decidim::Env.new("DECIDIM_AUDIT_RETENTION_PERIOD_DAYS", "365").to_i
  end
  # rubocop:enable Metrics/ParameterLists
end
