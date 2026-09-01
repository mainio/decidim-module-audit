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

      class << self
        # Allows auditing multiple classes with a single call, so instead of:
        #   Foo.audit_read(:read) do
        #     Bar.audit_read(:read) do
        #       do_something
        #     end
        #   end
        #
        # You can call:
        #   Auditable.audit_read_multiple(:read, Foo, Bar) do
        #     do_something
        #   end
        def audit_read_multiple(event = nil, *class_list, &block)
          class_list.reduce(block) do |inner, auditable|
            -> { auditable.audit_read(event, &inner) }
          end.call
        end
      end

      # Stores the queried record IDs during the request when the audit flag
      # is set. This is used to audit the read actions against the specified
      # auditable records.
      class RecordStore
        class << self
          def for(klass, flag = klass.audit_flag)
            return unless flag

            @stores ||= {}
            @stores[klass] ||= {}
            @stores[klass][flag] ||= new
          end

          def clear(klass, flag)
            return false unless @stores
            return false unless @stores[klass]

            @stores[klass].delete(flag)
            @stores.delete(klass) if @stores[klass].empty?
            remove_instance_variable(:@stores) if @stores.empty?

            true
          end
        end

        def initialize
          clear
        end

        def add(*ids)
          data.push(*ids)
        end

        def get
          data
        end

        def clear
          @data = []
        end

        private

        attr_reader :data
      end

      included do
        after_create -> { audit_changes(:create) }
        after_update -> { audit_changes(:update) }, if: :saved_changes?
        before_destroy :audit_destroy

        # The `after_find` method covers all the possible cases when the record
        # can be queried, including:
        # - Finding a single record, e.g. `Decidim::User.find(1)` or
        #   `Decidim::User.find_by(email: "admin@example.org")`
        # - Finding a collection of records, e.g.
        #   `Decidim::User.where(organization: 1, admin: true)`
        # - Fetching the record through an association, e.g.
        #   * `organization.users.where(admin: true)`
        #   * `audit_log.user`,
        #   * `moderation.reportable.author`
        # - Fetching the records through an `.includes()` statement within the
        #   query, e.g. `Decidim::ActionLog.includes(:user).first`
        #   * Note that in this particular case, fetching the records happens
        #     in a queries batch and the records are not fetched through the
        #     regular ActiveRecord scoping methods, such as `Record.all`,
        #     `Record.unscoped` or `Record.find_by_sql` as it would otherwise
        #     happen.
        #
        # Without this, all the association reflections for this class should
        # be modified across the whole application in order to catch all the
        # possible cases.
        #
        # This should not cause any relevant performance degregation compared
        # to auditing all the possible cases (some of which listed above) and
        # fetching the IDs from the record set instead of single records. This
        # is because the records are anyways initiated at some point. We only
        # audit that once the record is found, we mark it as audited during the
        # `audit_read` block.
        after_find :audit_find, if: -> { self.class.audit_flag.present? }
      end

      class_methods do
        attr_reader :audit_flag

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

        def audit_read(event, message: nil, details: nil, &)
          with_audit_lock(event) do
            with_audit_flag(event) { yield }

            # Collect the record IDs from the current class as well as all
            # superclasses.
            record_ids = []
            target = self
            while target.include?(Decidim::Audit::Auditable)
              store = RecordStore.for(target, event)
              record_ids += store.get.flatten if store
              target = target.superclass
            end
            record_ids.uniq!
            return if record_ids.empty?

            if event == :read && record_ids.length == 1
              Decidim::Audit.log(
                channel: table_name,
                event:,
                level: :info,
                message:,
                resource_id: record_ids.first,
                resource_type: polymorphic_name,
                details:
              )
            else
              details ||= {}
              details[:ids] = record_ids
              Decidim::Audit.log(
                channel: table_name,
                event:,
                level: :info,
                message:,
                details:
              )
            end
          ensure
            RecordStore.clear(self, event)
          end
        end

        def with_audit_flag(flag)
          prev_flag = @audit_flag
          @audit_flag = flag

          if superclass.respond_to?(:with_audit_flag, true)
            superclass.send(:with_audit_flag, flag) { yield }
          else
            yield
          end
        ensure
          if prev_flag
            @audit_flag = prev_flag
          else
            remove_instance_variable(:@audit_flag)
          end
        end

        def with_audit_lock(event)
          @audit_mutex_registry ||= {}
          mutex = (@audit_mutex_registry[event] ||= Mutex.new)

          return yield if mutex.locked? && mutex.owned?

          mutex.synchronize { yield }
        end

        private :with_audit_flag, :with_audit_lock
      end

      private

      def audit_find
        RecordStore.for(self.class).add(id)
      end

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
