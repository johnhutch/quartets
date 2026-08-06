# Claim-on-auth (ADR-0005, widened by ADR-0025): everything a visitor did on a
# cookie moves onto their account the moment they authenticate.
#
# A Warden hook rather than a controller filter, because a filter can't see that
# moment. It fired on sign-*in* (Devise has already authenticated by the time
# ApplicationController's filters run) but never on sign-*up*, where the claim
# only landed on the following request — the redirect. It worked in a browser and
# nowhere else, off Devise's internal filter ordering.
#
# `except: :fetch` is the three moments that can produce work to claim — password
# login, signup, remembered re-auth — each exactly once. Deserializing an
# already-signed-in user on every later request is `:fetch`, and is not an
# authentication. Devise writes its own remember cookie from this same hook, so
# touching cookies here is a supported pattern.
#
# There was briefly a second `only: :fetch` hook here, to catch sessions already
# authenticated when this shipped. It was removed as unverifiable: its trigger is
# a session that predates the deploy, which no test can construct, and mutation
# testing confirmed the whole suite passed with it deleted. The case it covered
# resolves on its own — a Rails session cookie dies with the browser, so those
# users re-authenticate through rememberable (a `:authentication` event) within a
# browser restart, and their work is claimed then.
Warden::Manager.after_set_user except: :fetch do |user, auth, _opts|
  next unless user.is_a?(User)

  cookies = auth.request.cookie_jar
  creator_token = cookies.signed[:creator_token]

  AnonymousClaim.new(user: user, creator_token: creator_token,
                     player_token: cookies.signed[:player_token]).call

  # The author token existed only to stand in for an account; now there is one.
  # The play token stays — attempts_controller still stamps every attempt with it.
  cookies.delete(:creator_token) if creator_token.present?
end
