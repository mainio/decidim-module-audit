# frozen_string_literal: true

class CreateDecidimAuditLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :decidim_audit_logs do |t|
      t.integer :decidim_organization_id, foreign_key: true
      t.integer :level, null: false, default: 0
      t.string :channel, null: false
      t.string :event, null: false
      t.string :message
      t.jsonb :details
      t.string :actor
      t.jsonb :request_details
      t.string :resource_type
      t.integer :resource_id
      t.jsonb :resource_changes
      t.datetime :created_at

      t.index :channel
      t.index :event
      t.index :actor
      t.index [:resource_type, :resource_id]
    end

    reversible do |direction|
      direction.up do
        # The rule is automatically dropped for down direction migration as the
        # whole table is dropped.
        execute "CREATE RULE protect_decidim_audit_logs_update AS ON UPDATE TO decidim_audit_logs DO INSTEAD nothing"
      end
    end
  end
end
