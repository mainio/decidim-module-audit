# frozen_string_literal: true

module Decidim
  # This namespace holds the logic of the `Audit` functionality.
  module Audit
    class Request
      delegate :request_id, :remote_ip, :session, to: :req

      def initialize(req)
        @req = req
      end

      def organization
        @organization ||= req.env["decidim.current_organization"]
      end

      def actor
        warden&.user(scope: :user) || visitor
      end

      def visitor
        @visitor ||= Decidim::Audit::Actor::Visitor.from_request(req)
      end

      def details
        {
          request_id: req.request_id,
          request_method: req.request_method,
          request_path: req.path,
          ip: req.ip,
          remote_ip: req.remote_ip,
          user_agent: req.get_header("HTTP_USER_AGENT"),
          sec_ch_ua: req.get_header("HTTP_SEC_CH_UA"),
          sec_ch_ua_mobile: req.get_header("HTTP_SEC_CH_UA_MOBILE"),
          sec_ch_ua_platform: req.get_header("HTTP_SEC_CH_UA_PLATFORM")
        }
      end

      private

      attr_reader :req

      def warden
        req.env["warden"]
      end
    end
  end
end
