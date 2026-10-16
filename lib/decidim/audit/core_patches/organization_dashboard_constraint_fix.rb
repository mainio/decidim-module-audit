# frozen_string_literal: true

module Decidim
  module Audit
    module CorePatches
      # This adds an authentication option to the `warden.authenticate!` call
      # that we can detect in the before_failure hook. These redirects should
      # not be considered authentication failures as they are normal requests to
      # any path under the admin engine.
      #
      # Without this, all unauthenticated requests under the `/admin` would
      # cause an authentication failure, which can cause noise in the audit logs
      # as many bots are looking for specific URLs under that path. Instead of
      # an authentication failure, these requests should be considered as
      # unauthenticated requests that do not cause any harm.
      #
      # REF: decidim/decidim#17889
      module OrganizationDashboardConstraintFix
        extend ActiveSupport::Concern

        included do
          private

          def user
            return unless request.env["warden"].authenticate!(scope: :user, context: :admin_constraint)

            @user ||= request.env["warden"].user(scope: :user)
          end
        end
      end
    end
  end
end
