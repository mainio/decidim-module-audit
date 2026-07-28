# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "decidim/audit/version"

Gem::Specification.new do |s|
  s.name = "decidim-audit"
  s.version = Decidim::Audit.version
  s.authors = ["Antti Hukkanen"]
  s.email = ["antti.hukkanen@mainiotech.fi"]
  s.required_ruby_version = "~> 3.2"

  s.metadata["rubygems_mfa_required"] = "true"

  s.summary = "An audit module"
  s.description = "Adds audit logging capabilities to the platform."
  s.homepage = "https://github.com/mainio/decidim-module-audit"
  s.license = "AGPL-3.0"

  s.files = Dir[
    "{app,config,lib}/**/*",
    "LICENSE-AGPLv3.txt",
    "Rakefile",
    "README.md"
  ]

  s.add_dependency "decidim-core", Decidim::Audit.decidim_version
end
