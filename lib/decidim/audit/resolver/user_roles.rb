# frozen_string_literal: true

module Decidim
  module Audit
    module Resolver
      # Resolves all user roles.
      class UserRoles
        def self.for(actor)
          return unless actor.is_a?(Decidim::UserBaseEntity)

          new(actor).resolve
        end

        def initialize(user)
          @user = user
        end

        def resolve
          (user_roles + space_roles).presence
        end

        private

        attr_reader :user

        def user_roles
          user.roles || []
        end

        def space_roles
          q = query
          return [] unless query

          connection.exec_query(q).rows.map { |r| r.join("_") }
        end

        def role_types
          {}.tap do |types|
            types[:assembly] = [Decidim::AssemblyUserRole, :decidim_assembly_id] if Decidim.module_installed?(:assemblies)
            types[:conference] = [Decidim::ConferenceUserRole, :decidim_conference_id] if Decidim.module_installed?(:conferences)
            types[:process] = [Decidim::ParticipatoryProcessUserRole, :decidim_participatory_process_id] if Decidim.module_installed?(:participatory_processes)
          end
        end

        def query
          queries = role_types.map do |key, (role_class, space_id_column)|
            <<~SQL.squish
              SELECT
                #{connection.quote(key)} AS space_type,
                #{connection.quote_column_name(space_id_column)} AS space_id,
                #{connection.quote_column_name("role")}
                FROM #{connection.quote_table_name(role_class.table_name)}
                WHERE decidim_user_id = :user_id
            SQL
          end
          return if queries.empty?

          ActiveRecord::Base.sanitize_sql_array(
            [
              queries.join(" UNION ALL "),
              { user_id: user.id }
            ]
          )
        end

        def connection
          ActiveRecord::Base.connection
        end
      end
    end
  end
end
