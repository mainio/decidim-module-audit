# frozen_string_literal: true

module Decidim
  module Audit
    module Actor
      class Visitor
        include GlobalID::Identification

        TYPE_SESSION = "S"
        TYPE_REQUEST = "R"

        class << self
          def from_request(request)
            type, identifier, uuid =
              if request.session
                [TYPE_SESSION, request.session.id]
              else
                [TYPE_REQUEST, request.requestid, request.uuid]
              end

            new(type, identifier, uuid, request.remote_ip)
          end

          def find(id, params = {})
            raise InvalidIdError unless id.is_a?(Array)
            raise InvalidIdError unless (2..3).include?(id.length)

            type, identifier, uuid = id
            raise InvalidIdError unless type.is_a?(String)
            raise InvalidIdError unless type.in?([TYPE_SESSION, TYPE_REQUEST])
            raise InvalidIdError if identifier.blank?

            new(type, identifier, uuid, params[:ip])
          end
        end

        attr_reader :type, :identifier, :uuid, :ip

        def initialize(type, identifier, uuid, ip)
          @type = type
          @identifier = identifier
          @uuid = uuid if type == TYPE_REQUEST
          @ip = ip
        end

        def ==(other)
          [:type, :identifier, :uuid, :ip].all? { |key| public_send(key) == other.public_send(key) }
        end

        def id
          if type == TYPE_REQUEST
            [type, identifier, uuid]
          else
            [type, identifier]
          end
        end

        def to_global_id(options = {})
          super(options.merge(default_gid_options))
        end
        alias to_gid to_global_id

        def to_signed_global_id(options = {})
          super(options.merge(default_gid_options))
        end
        alias to_sgid to_signed_global_id

        private

        def default_gid_options
          { app: "decidim-audit-module", ip: }
        end

        class InvalidIdError < StandardError; end
      end
    end
  end
end
