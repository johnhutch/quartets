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

  # Three outcomes. A registration flags the request on its way in, because the
  # winning strategy can't distinguish one — a post-password-reset sign_in is also
  # strategy-less, and that one genuinely is somebody who had to type their way
  # back in. Everything else splits on whether the remember cookie did the work.
  #
  # Signups were originally folded into `signed_in` as "password-equivalent". They
  # aren't, for the one measurement this exists to serve: a signup is a new
  # account, not a session that failed to last, and counting it as a forced
  # re-login made the dashboard's headline number rise with new-user growth.
  event_type =
    if auth.request.env[Users::RegistrationsController::SIGNING_UP]
      :signed_up
    elsif auth.winning_strategy.is_a?(Devise::Strategies::Rememberable)
      :signed_in_remembered
    else
      :signed_in
    end

  Event.create!(
    event_type: event_type,
    user: user,
    # Present when they've already touched a play surface; nil is fine and
    # expected on a first-ever signup (Event only requires it for play events).
    player_token: auth.request.cookie_jar.signed[:player_token]
  )
rescue StandardError
  nil # best-effort: analytics must never break or slow down signing in
end
