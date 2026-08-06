# Session-health instrumentation (analytics stream B).
#
# Every authentication that actually sets a user records one Event, tagged by
# *how* they got in: typing a password (`signed_in`) or riding the remember
# cookie (`signed_in_remembered`). The ratio is the whole measurement — a rising
# password share means sessions aren't surviving and people are having to log
# back in, which trackable's sign_in_count can't tell you on its own (it counts
# sign-ins without saying what caused them).
#
# `except: :fetch` is what keeps this honest: pulling an already-signed-in user
# out of the session on every request fires `after_set_user` too, and that is not
# a sign-in. What's left is `:authentication` (a strategy won — password or
# remember cookie) and `:set_user` (a programmatic sign_in, i.e. registration).
Warden::Manager.after_set_user except: :fetch do |user, auth, _opts|
  next unless user.is_a?(User)

  # winning_strategy is nil for a programmatic sign_in (registration), which is a
  # password-equivalent event — somebody just typed credentials into a form.
  remembered = auth.winning_strategy.is_a?(Devise::Strategies::Rememberable)

  Event.create!(
    event_type: remembered ? :signed_in_remembered : :signed_in,
    user: user,
    # Present when they've already touched a play surface; nil is fine and
    # expected on a first-ever signup (Event only requires it for play events).
    player_token: auth.request.cookie_jar.signed[:player_token]
  )
rescue StandardError
  nil # best-effort: analytics must never break or slow down signing in
end
