# frozen_string_literal: true

Warden::Manager.after_authentication do |record, _warden, options|
  scope = options[:scope]

  Decidim::Audit.log(
    channel: "authentication",
    event: "success",
    details: { scope: },
    resource: record
  )
end

Warden::Manager.before_failure do |env, options|
  scope = options[:scope]
  message = options[:message]
  action = options[:action]
  path = options[:attempted_path]

  params = env["action_dispatch.request.parameters"]
  sign_in_params = params[scope] if params
  resource = Decidim::User.find_by(email: sign_in_params[:email]) if sign_in_params.is_a?(Hash)

  # Note that this does not catch OmniAuth authentication failures. They are
  # handled separately through a before_action hook at
  # Decidim::Audit::OmniauthCallbacksExtension.
  Decidim::Audit.log(
    channel: "authentication",
    event: "failure",
    level: :notice,
    message:,
    details: { scope:, action:, path: },
    resource:
  )
end

Warden::Manager.before_logout do |record, _warden, options|
  # This is called for all scopes concecutively, so if the record does not
  # exist, it is not the correct scope currently being logged out.
  next unless record

  scope = options[:scope]

  Decidim::Audit.log(
    channel: "authentication",
    event: "logout",
    details: { scope: },
    resource: record
  )
end
