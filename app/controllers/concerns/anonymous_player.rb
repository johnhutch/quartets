# Anonymous, login-free identity for players. A signed cookie so Phase 4 stats can
# attribute plays to a "player" without any account. Shared by every public
# surface that can be played from (home + the play pages).
#
# The cookie's lifespan tracks the login's. It used to be `permanent` — twenty
# years — which outlived every session by a wide margin, so a lapsed login left a
# visitor looking at a personalised "your solved puzzles" page while the menu
# offered LOG IN. Both identities expire together now, which is the only thing
# that stops it: PlayerCompletions falls back to this token the moment the account
# identity is gone, and it can only fall back to a cookie that still exists.
module AnonymousPlayer
  extend ActiveSupport::Concern
  include IdentityCookies

  included do
    before_action :ensure_player_token
    helper_method :current_player_token
  end

  private

  # Seeds the memo with what was just written, so the read below doesn't verify
  # the same signed cookie a second time.
  def ensure_player_token
    @current_player_token = write_identity_cookie(:player_token, expires: player_token_expires_at)
  end

  # Memoized: reading a signed cookie is a fresh HMAC + JSON parse every time, and
  # a single play page reads this four times. `ensure_player_token` is the only
  # writer and runs first, so the memo can't go stale within a request.
  def current_player_token
    @current_player_token ||= cookies.signed[:player_token]
  end

  # One rule with one exception. The token carries the same lifespan as the login
  # (config.x.identity_lifespan, which is where Devise's remember_for comes from)
  # and slides on the same policy, so neither meaningfully outlives the other. The
  # exception is a session-only login: they said don't remember me, so the play
  # identity shouldn't outlive the browser either.
  #
  # This used to try to pin the expiry to `remember_created_at + remember_for`, on
  # the belief that it was Devise's own arithmetic. It isn't, and the bug was
  # severe: `Devise::Models::Rememberable#remember_me!` sets
  # `remember_created_at ||= Time.now.utc` — it never advances — while the cookie
  # it writes is always `remember_for.from_now`. So the computed value drifted
  # further into the past on every re-auth, and once it went negative the cookie
  # was written already-expired, read back nil in the same request, and minted a
  # fresh uuid every time — taking mid-game saves (NOT NULL player_token) and the
  # game_started beacon down with it. Do not reintroduce that pinning.
  def player_token_expires_at
    return nil if session_only_login?

    identity_lifespan.from_now
  end

  # Signed in without a live remember cookie. Note the known imprecision: Devise
  # only clears `remember_user_token` on explicit sign-out, so someone who once
  # ticked "Stay logged in" and later signs in without it still carries the old
  # cookie and is read as remembered here. That cookie is genuinely still valid —
  # rememberable will sign them back in with it — so treating it as a remembered
  # login describes the browser's real state rather than the checkbox's intent.
  def session_only_login?
    user_signed_in? && cookies[:remember_user_token].blank?
  end
end
