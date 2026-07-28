# frozen_string_literal: true

require "decidim/audit/commands/session"

module Decidim
  module Audit
    module Commands
      module IRBConsoleExtension
        extend ActiveSupport::Concern

        included do
          class << self
            alias_method :audit_orig_start, :start unless method_defined?(:audit_orig_start)

            def start
              Decidim::Audit::Commands::Session.wrap do
                audit_orig_start
              end
            end
          end
        end
      end
    end
  end
end
