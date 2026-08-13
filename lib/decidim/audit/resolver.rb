# frozen_string_literal: true

module Decidim
  module Audit
    module Resolver
      autoload :ActorDetails, "decidim/audit/resolver/actor_details"
      autoload :ActorType, "decidim/audit/resolver/actor_type"
      autoload :UserRoles, "decidim/audit/resolver/user_roles"
    end
  end
end
