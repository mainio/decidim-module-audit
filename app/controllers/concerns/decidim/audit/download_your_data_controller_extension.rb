# frozen_string_literal: true

module Decidim
  module Audit
    # Audits the download your data export and download requests.
    module DownloadYourDataControllerExtension
      extend ActiveSupport::Concern

      included do
        before_action :audit_read, only: [:export, :download_file] # rubocop:disable Rails/LexicallyScopedActionFilter
      end

      private

      def audit_read
        Decidim::Audit.log(
          channel: "download_your_data",
          event: action_name,
          details: { controller: self.class.name },
          level: :info
        )
      end
    end
  end
end
