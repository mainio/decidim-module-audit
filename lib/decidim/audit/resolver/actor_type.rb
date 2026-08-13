# frozen_string_literal: true

module Decidim
  module Audit
    module Resolver
      # Resolves actor type.
      class ActorType
        def self.for(actor)
          return unless actor

          new(actor).resolve
        end

        def initialize(actor)
          @actor = actor
        end

        def resolve
          return "app_admin" if Decidim.module_installed?(:system) && actor.is_a?(Decidim::System::Admin)

          case actor
          # Uncomment after 0.31 update
          # when Decidim::Api::ApiUser
          #   "organization_api_user"
          when Decidim::UserBaseEntity
            if actor.respond_to?(:admin) && actor.admin?
              "organization_admin"
            else
              "organization_user"
            end
          when Decidim::Audit::Actor::SystemUser
            "system_user"
          when Decidim::Audit::Actor::Visitor
            "visitor"
          end
        end

        private

        attr_reader :actor
      end
    end
  end
end
