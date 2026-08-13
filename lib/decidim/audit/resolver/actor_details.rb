# frozen_string_literal: true

module Decidim
  module Audit
    module Resolver
      # Resolves actor details to be included in the log records.
      class ActorDetails
        def self.for(actor)
          new(actor)
        end

        attr_reader :type, :roles

        def initialize(actor)
          @type = ActorType.for(actor)
          @roles = UserRoles.for(actor)
        end
      end
    end
  end
end
