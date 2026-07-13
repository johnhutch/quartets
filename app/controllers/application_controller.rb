class ApplicationController < ActionController::Base
  # Rate-limit counters live in the shared app cache (solid_cache in prod) so they
  # hold across Puma workers. We delegate to Rails.cache at request time instead of
  # letting rate_limit capture the store at class-load: the test env's null_store
  # never counts, so specs can swap Rails.cache for a real store to exercise limits.
  RATE_LIMIT_STORE = Object.new.tap do |store|
    def store.increment(name, amount = 1, **options)
      Rails.cache.increment(name, amount, **options)
    end
  end

  # Anonymous authors' puzzles get claimed onto their account the moment they
  # authenticate (ADR-0005).
  include ClaimsPuzzles

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # First-party traffic log (analytics stream A) — path + referrer + UA, no IP,
  # no cookie. Server-side, best-effort, after the response is built.
  after_action :log_visit

  # Devise's default permit list doesn't know our extra column; display_name is
  # asked at signup and editable in account settings.
  before_action :configure_devise_params, if: :devise_controller?

  # Root is the public homepage now, so send a freshly signed-in author to their
  # dashboard instead of the visitor-facing front door.
  def after_sign_in_path_for(_resource)
    puzzles_path
  end

  private

  # Log a page view: successful, top-level HTML GETs only — skip assets, admin
  # (staff browsing isn't traffic), infra paths, Turbo-frame partials, and XHR.
  # Bots are logged too, flagged, so they're counted apart from humans.
  SKIP_VISIT_PATHS = %w[/up /sitemap.xml /robots.txt /manifest].freeze

  def log_visit
    return unless request.get? && request.format.html? && response.successful?
    return if request.xhr? || request.headers["Turbo-Frame"].present?
    return if request.path.start_with?("/assets", "/admin", "/rails")
    return if SKIP_VISIT_PATHS.include?(request.path)

    Visit.create!(path: request.path, referrer: request.referer,
                  user_agent: request.user_agent, bot: BotDetector.bot?(request.user_agent))
  rescue StandardError
    nil # best-effort: a missed log never affects the visitor
  end

  # One grouped query of play counts for a set of puzzles, keyed by puzzle_id, so
  # list rows can show "N plays" without firing attempts.count per row (N+1).
  def play_counts_for(puzzles)
    Attempt.where(puzzle_id: puzzles.map(&:id)).group(:puzzle_id).count
  end

  def configure_devise_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:display_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:display_name])
  end
end
