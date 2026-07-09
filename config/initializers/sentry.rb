# Production error monitoring. Only initializes when SENTRY_DSN is present, so
# dev, test, and an un-configured production all stay silent — nothing phones
# home until you set the DSN in the NAS .env.
#
# Privacy: send_default_pii stays FALSE (the SDK default, pinned here for intent).
# That keeps request bodies, cookies, headers, and user IPs out of every event —
# we get stack traces + code context, not user data. Matches the site's stated
# stance (footer / robots.txt): we don't creep on people, and that includes not
# shipping their data to a third party to debug our own crashes.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.enabled_environments = %w[production]
    config.environment = Rails.env
    config.send_default_pii = false

    # Errors only — no performance/tracing spans (keeps us well inside the free
    # tier; we want "what broke", not latency histograms).
    config.traces_sample_rate = 0.0

    # Tag events with the running image's commit so we can see which deploy
    # introduced a regression (the compose file passes GIT_SHA; nil if unset).
    config.release = ENV["GIT_SHA"].presence

    # Expected, non-bug noise — bad URLs from crawlers, unparseable requests —
    # on top of Sentry's built-in excludes (RecordNotFound et al.). Keeps the
    # signal high and doesn't burn quota on 404s.
    config.excluded_exceptions += %w[
      ActionController::RoutingError
      ActionController::BadRequest
      ActionController::UnknownFormat
      ActionController::UnpermittedParameters
    ]
  end
end
