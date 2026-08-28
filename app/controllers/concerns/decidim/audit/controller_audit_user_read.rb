# frozen_string_literal: true

module Decidim
  module Audit
    module ControllerAuditUserRead
      extend ActiveSupport::Concern

      def self.configure(&)
        instance_exec(&)
      end

      def self.audit_controller(klass, channel: nil, events: nil, actions: nil, request_methods: :GET)
        klass.include(self)
        klass.audit_channel(channel || "users_admin")
        klass.audit_events(events)
        klass.audit_restrict_actions(actions) if actions
        klass.audit_restrict_request_methods(request_methods) if request_methods
      end

      included do
        around_action :audit_read, if: :audit_read?
      end

      class_methods do
        def audit_channel(channel = nil)
          @audit_channel = channel if channel
          @audit_channel || superclass.try(__method__)
        end

        def audit_events(events = nil)
          @audit_events = events.to_h { |k, v| [k.to_sym, v.to_sym] } if events.is_a?(Hash)
          @audit_events || superclass.try(__method__)
        end

        def audit_restrict_actions(actions = nil)
          @audit_restrict_actions = Array(actions).map(&:to_sym) if actions
          @audit_restrict_actions || superclass.try(__method__)
        end

        def audit_restrict_request_methods(methods = nil)
          @audit_restrict_request_methods = Array(methods).map(&:to_sym) if methods
          @audit_restrict_request_methods || superclass.try(__method__)
        end
      end

      private

      def audit_read?
        methods = self.class.audit_restrict_request_methods
        return false if methods&.exclude?(request.method.to_sym)

        actions = self.class.audit_restrict_actions
        return false if actions&.exclude?(action_name.to_sym)

        true
      end

      def audit_read
        Decidim::Audit.log(
          channel: self.class.audit_channel,
          event: action_name,
          details: { controller: self.class.name },
          level: :info
        )

        action = action_name.to_sym
        event = self.class.audit_events[action] if self.class.audit_events
        event ||= action_name.to_sym == :index ? :read_list : :read
        Decidim::User.audit_read(event) do
          yield
        end
      end
    end
  end
end
