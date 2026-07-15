require "active_support/core_ext/integer/time"

# Loose files in public/ (robots.txt, favicon, the social share image…) inherit
# the far-future asset cache below — but unlike digest-stamped assets they aren't
# content-hashed, so an edit gets pinned at the CDN/browser for a year (this is
# what stranded a stale robots.txt at Cloudflare). Downgrade just those paths to a
# short cache so changes propagate; the hashed /assets/ keep their immutable year.
class ShortLivedLoosePublicFiles
  PATHS = %w[
    /robots.txt /favicon.ico /icon.svg /icon.png /apple-touch-icon.png /share.png
  ].freeze

  def initialize(app) = @app = app

  def call(env)
    status, headers, body = @app.call(env)
    headers["cache-control"] = "public, max-age=3600" if PATHS.include?(env["PATH_INFO"])
    [status, headers, body]
  end
end

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
  # …but short-cache the non-hashed loose public/ files (robots.txt, favicon, …).
  config.middleware.insert_before ActionDispatch::Static, ShortLivedLoosePublicFiles if config.public_file_server.enabled

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com") }

  # Outbound mail. Prefer Resend's HTTP API (port 443) — SMTP ports are unreliable
  # from the self-hosted NAS (partial IP reachability behind the ISP causes
  # Net::OpenTimeout). The API rides HTTPS, which is rock-solid here. Falls back to
  # SMTP if only SMTP_* is configured (e.g. another host); mail is off until one is
  # set, and errors stay swallowed until then so the app boots clean.
  if ENV["RESEND_API_KEY"].present?
    config.action_mailer.delivery_method = :resend # registered by the resend gem's railtie
    config.action_mailer.raise_delivery_errors = true
  else
    config.action_mailer.raise_delivery_errors = ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:        ENV["SMTP_ADDRESS"],
      port:           ENV.fetch("SMTP_PORT", 587).to_i,
      user_name:      ENV["SMTP_USERNAME"],
      password:       ENV["SMTP_PASSWORD"],
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: true
    }
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Host authorization. Public traffic arrives through a Cloudflare Tunnel as
  # `playquartets.com`; `web`/`localhost` cover the internal compose origins the
  # tunnel and health checks use. (Direct NAS-IP access is intentionally not
  # listed — go through the domain.)
  config.hosts += %w[playquartets.com www.playquartets.com web localhost]

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
