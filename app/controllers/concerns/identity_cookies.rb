# One place that knows what an anonymous identity cookie *is*.
#
# There are two — `player_token` (AnonymousPlayer) and `creator_token` (Creator) —
# and they agree on everything except how long they last: a signed cookie holding
# an opaque uuid, re-stamped each request so the expiry slides, never permanent.
# That last rule is ADR-0025's policy, and it lives here so the two can't drift
# apart again — which is exactly what happened when ADR-0024 shortened one and
# left the other at twenty years.
module IdentityCookies
  extend ActiveSupport::Concern

  private

  # Written on every request rather than only when missing, because the expiry has
  # to keep sliding and a browser never reports what it's holding. The value is
  # preserved across rewrites; only the expiry moves.
  def write_identity_cookie(name, expires:)
    cookies.signed[name] = { value: cookies.signed[name] || SecureRandom.uuid, expires: expires }
  end

  # The site's identity lifespan — and the value Devise's `remember_for` is set
  # from (config/application.rb), so "the login and the cookies expire together" is
  # one number rather than three call sites agreeing by hand.
  def identity_lifespan
    Rails.application.config.x.identity_lifespan
  end
end
