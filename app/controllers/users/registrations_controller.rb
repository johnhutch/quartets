# Signing up has to mean the same thing as signing in: you stay signed in.
#
# Stock Devise `registrations#create` signs the new account in through the
# *session* cookie only — it never touches rememberable. So a fresh signup lasted
# exactly as long as the browser kept the session around, which on iOS Safari is
# not long at all, and the new account got dumped back to logged-out within a day
# or two. The sign-in form has always offered "Stay logged in" (checked by
# default, app/views/devise/sessions/new.html.erb); nobody signs *up* intending to
# be logged out by tomorrow either, so registration now sets the same cookie.
#
# Everything else stays stock — display_name is permitted by
# ApplicationController#configure_devise_params, which still runs here.
class Users::RegistrationsController < Devise::RegistrationsController
  # Not included in controllers by default — Devise ships it as opt-in.
  include Devise::Controllers::Rememberable

  # Read by the session-events hook (config/initializers/session_events.rb), which
  # otherwise can't tell a registration from any other programmatic sign-in — a
  # password reset also signs you in with no winning strategy, and that one really
  # is somebody who had to type their way back in.
  SIGNING_UP = "quartets.signing_up".freeze

  def create
    # Set before `super`, since the hook fires inside it. Harmless on a failed
    # signup: nothing authenticates, so the hook never runs.
    request.env[SIGNING_UP] = true
    super
    # `super` renders or redirects; cookies set after that still ride the response.
    # Guarded on persisted? because a failed signup re-renders the form with an
    # unsaved resource, which has nothing to remember.
    remember_me(resource) if resource.persisted?
  end
end
