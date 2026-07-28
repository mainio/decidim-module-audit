# frozen_string_literal: true

module Decidim
  module Audit
    # Module that can be attached to any record that needs to be audited for its
    # changes. Note that this will not log any updates that bypass the
    # validations, such as `update_all`, `update_column` or `update_columns`.
    # Because of this, is recommended to add also additional DB-level logging
    # for specified records through PGAudit.
    module Auditable
      extend ActiveSupport::Concern

      included do
        after_create -> { audit_changes(:create) }
        after_update -> { audit_changes(:update) }, if: :saved_changes?
        before_destroy :audit_destroy
      end

      class_methods do
        def auditable_attributes
          @auditable_attributes ||= attribute_names - excluded_auditable_attributes
        end

        def excluded_auditable_attributes
          @excluded_auditable_attributes ||= []
        end

        def exclude_auditable_attributes!(*attributes)
          @excluded_auditable_attributes ||= []
          @excluded_auditable_attributes += attributes.map(&:to_s)
        end
      end

      private

      def audit_changes(event)
        Decidim::Audit.log(
          channel: self.class.table_name,
          event:,
          level: :info,
          resource: self,
          resource_changes: prepare_audit_resource_changes(saved_changes)
        )
      end

      def audit_destroy
        return if new_record?

        resource_changes = attributes.transform_values { |value| [value, nil] }
        Decidim::Audit.log(
          channel: self.class.table_name,
          event: "destroy",
          level: :info,
          resource: self,
          resource_changes: prepare_audit_resource_changes(resource_changes)
        )
      end

      def prepare_audit_resource_changes(resource_changes)
        return unless resource_changes

        resource_changes.select { |key| self.class.auditable_attributes.include?(key) }
      end
    end
  end
end
