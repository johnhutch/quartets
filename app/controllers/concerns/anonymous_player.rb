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

  def ensure_player_token
    write_identity_cookie(:player_token, expires: player_token_expires_at)
  end

  # Memoized: reading a signed cookie is a fresh HMAC + JSON parse every time, and
  # a single play page reads this four times. `ensure_player_token` is the only
  # writer and runs first, so the memo can't go stale within a request.
  def current_player_token
    @current_player_token ||= cookies.signed[:player_token]
  end

  # A remembered login pins the token to that cookie's *own* expiry — same
  # `remember_created_at + remember_for` arithmetic Devise uses, so the two can't
  # drift. A session-only login gets a session cookie (nil expiry): they said
  # don't remember me, so nothing should outlive the browser. Signed out there's
  # no login to outlive, so it just slides.
  def player_token_expires_at
    return identity_lifespan.from_now unless user_signed_in?
    return nil unless remembered_login?

    (current_user.remember_created_at || Time.current) + Devise.remember_for
  end

  # The login cookie as the browser actually holds it. Reading `remember_created_at`
  # instead would lie after a session-only sign-in, since a previous remembered
  # login leaves that column set.
  def remembered_login?
    cookies[:remember_user_token].present?
  end
end
