# frozen_string_literal: true

module Decidim
  module Audit
    module Actor
      autoload :Visitor, "decidim/audit/actor/visitor"
      autoload :SystemUser, "decidim/audit/actor/system_user"
    end
  end
end
