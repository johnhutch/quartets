# Anonymous, login-free identity for players. A signed cookie so Phase 4 stats can
# attribute plays to a "player" without any account. Shared by every public
# surface that can be played from (home + the play pages).
#
# The cookie's *lifespan tracks the login's*. It used to be `permanent` — twenty
# years — which outlived every session by a wide margin, so a lapsed login left a
# visitor looking at a personalised "your solved puzzles" page while the menu
# offered LOG IN. Both identities expire together now, which is the only thing
# that actually stops that: PlayerCompletions falls back to this token the moment
# the account identity is gone, and it can only fall back to a cookie that still
# exists.
module AnonymousPlayer
  extend ActiveSupport::Concern

  included do
    before_action :ensure_player_token
    helper_method :current_player_token
  end

  private

  # Written on every request, not only when missing, because the *expiry* has to
  # keep tracking the login cookie and a browser never tells us what it's holding.
  # The token value itself is preserved — only the expiry moves.
  def ensure_player_token
    cookies.signed[:player_token] = {
      value: current_player_token || SecureRandom.uuid,
      expires: player_token_expires_at
    }
  end

  def current_player_token
    cookies.signed[:player_token]
  end

  # Three cases, and the middle one is the point of the exercise:
  #
  #   signed in + remembered    → pin to the remember cookie's own expiry, off the
  #                               same remember_created_at + remember_for Devise
  #                               uses, so the two can't drift apart
  #   signed in, not remembered → a session cookie, matching a session-only login:
  #                               they said don't remember me, so nothing outlives
  #                               the browser session
  #   signed out                → remember_for from now, sliding. There's no login
  #                               to outlive, and an anonymous regular shouldn't
  #                               lose their history for visiting on a schedule.
  def player_token_expires_at
    return Devise.remember_for.from_now unless user_signed_in?
    return nil unless remembered_login? # nil expiry = session cookie

    remembered_at = current_user.remember_created_at
    remembered_at ? remembered_at + Devise.remember_for : Devise.remember_for.from_now
  end

  # The login cookie as the browser actually holds it — the honest signal. Reading
  # remember_created_at instead would lie after a session-only sign-in, since a
  # previous remembered login leaves that column set.
  def remembered_login?
    cookies[:remember_user_token].present?
  end
end
