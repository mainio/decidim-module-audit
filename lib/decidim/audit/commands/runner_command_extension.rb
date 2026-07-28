# frozen_string_literal: true

require "decidim/audit/commands/session"

module Decidim
  module Audit
    module Commands
      module RunnerCommandExtension
        extend ActiveSupport::Concern

        included do
          alias_method :audit_orig_eval, :eval unless method_defined?(:audit_orig_eval)

          Kernel = WrappedKernel

          private

          def eval(*)
            Decidim::Audit::Commands::Session.wrap do
              audit_orig_eval(*)
            end
          end
        end

        class WrappedKernel
          def self.load(*)
            Decidim::Audit::Commands::Session.wrap do
              ::Kernel.load(*)
            end
          end
        end
      end
    end
  end
end
