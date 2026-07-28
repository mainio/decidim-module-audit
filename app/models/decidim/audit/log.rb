# frozen_string_literal: true

module Decidim
  module Audit
    # Abstract class from which all models in this engine inherit.
    class Log < ApplicationRecord
      belongs_to :organization, foreign_key: "decidim_organization_id", class_name: "Decidim::Organization", optional: true
      belongs_to :resource, polymorphic: true, optional: true

      enum :level, {
        info: 0,
        notice: 1,
        warn: 2,
        error: 3,
        critical: 4,
        alert: 5,
        fatal: 6
      }

      validates :channel, presence: true
      validates :event, presence: true

      after_create :readonly!
      after_find :readonly!

      def actor_gid
        attributes["actor"]
      end

      def actor
        @actor ||= GlobalID::Locator.locate(super)
      end

      def logger_level
        self.class.levels[level]
      end
    end
  end
end
