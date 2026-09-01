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

  # The actor has to be manually defined here because otherwise this could lead
  # to an endless loop with Devise timeoutable. This happens when:
  # - Devise timeoutable calls `warden_proxy.sign_out`
  # - That would which would call this hook
  # - `Decidim::Audit.log` would call `current_request.actor`
  # - `current_request.actor` would call `warden_proxy.user` and
  #   `warden_proxy.set_user`
  # - This would fire the Devise timeoutable's `after_set_user` hook
  # - This loop would start from the beginning
  #
  # This is an edge case that can happen if the session cookie is still valid
  # and sent to the server but the timeout time has been already reached at
  # server side.
  actor = Decidim::Audit.current_request.visitor

  Decidim::Audit.log(
    channel: "authentication",
    event: "logout",
    details: { scope: },
    actor:,
    resource: record
  )
end
