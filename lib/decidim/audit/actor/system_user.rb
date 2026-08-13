# frozen_string_literal: true

module Decidim
  module Audit
    module Actor
      class SystemUser
        include GlobalID::Identification

        class << self
          def fetch
            pwuid = Etc.getpwuid
            new(pwuid.uid, pwuid.gid, pwuid.name, pwuid.gecos)
          end

          def find(id, params = {})
            raise InvalidIdError unless id.is_a?(Array)
            raise InvalidIdError unless id.length == 3

            uid, gid, name = id
            raise InvalidIdError unless [uid, gid].all? { |attribute| attribute.is_a?(Integer) || attribute.is_a?(String) }
            raise InvalidIdError unless name.is_a?(String)
            raise InvalidIdError if [uid, gid].any?(&:blank?)

            new(uid.to_i, gid.to_i, name, params[:gecos])
          end
        end

        attr_reader :uid, :gid, :name, :gecos

        def initialize(uid, gid, name, gecos)
          @uid = uid
          @gid = gid
          @name = name
          @gecos = gecos
        end

        def ==(other)
          [:uid, :gid, :name, :gecos].all? { |key| public_send(key) == other.public_send(key) }
        end

        def id
          [uid, gid, name]
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
          { app: "decidim-audit-module", gecos: }
        end

        class InvalidIdError < StandardError; end
      end
    end
  end
end
