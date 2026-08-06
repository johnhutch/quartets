# Claim-on-auth (ADR-0005, widened by ADR-0025): everything a visitor did on a
# cookie moves onto their account the moment they authenticate.
#
# Warden hooks rather than a controller filter, because a filter can't see that
# moment. It fired on sign-*in* (Devise has already authenticated by the time
# ApplicationController's filters run) but never on sign-*up*, where the claim
# only landed on the following request — the redirect. It worked in a browser and
# nowhere else, off Devise's internal filter ordering.
#
# Deliberately not rescued, unlike the analytics hook beside it: a claim that
# fails silently looks exactly like losing someone's puzzles.
sweep = lambda do |user, auth|
  cookies = auth.request.cookie_jar
  creator_token = cookies.signed[:creator_token]

  AnonymousClaim.new(user: user, creator_token: creator_token,
                     player_token: cookies.signed[:player_token]).call

  # The author token existed only to stand in for an account; now there is one.
  # The play token stays — attempts_controller still stamps every attempt with it.
  cookies.delete(:creator_token) if creator_token.present?
  auth.request.session[:claimed_for] = user.id
end

# The real one: password login, signup, and remembered re-auth — the three moments
# that can produce work to claim, each exactly once, no controller involved.
# Devise writes its own remember cookie from this same hook, so touching cookies
# here is a supported pattern.
Warden::Manager.after_set_user except: :fetch do |user, auth, _opts|
  next unless user.is_a?(User)

  sweep.call(user, auth)
end

# TRANSITIONAL — removable once every session predating ADR-0025 has expired,
# i.e. after 2026-11-06 (config.x.identity_lifespan from 2026-08-06).
#
# Sessions that were already authenticated when the widened claim shipped only
# ever fire `:fetch`, which the hook above ignores by design, so their anonymous
# plays would sit unclaimed until they next signed in — up to three months. The
# session flag keeps this to one sweep per session; after that it's a hash lookup.
Warden::Manager.after_set_user only: :fetch do |user, auth, _opts|
  next unless user.is_a?(User)
  next if auth.request.session[:claimed_for] == user.id

  sweep.call(user, auth)
end
