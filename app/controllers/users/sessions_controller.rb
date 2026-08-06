# Signing out clears the player identity too.
#
# Devise already drops the session and the remember cookie
# (expire_all_remember_me_on_sign_out). What it can't know about is player_token,
# the anonymous play identity — and leaving that behind is exactly what produced
# the orphan state: PlayerCompletions falls back to the token when there's no
# account, so a signed-out visitor kept seeing "your solved puzzles" as though
# nothing had happened. Logging out should mean logged out.
class Users::SessionsController < Devise::SessionsController
  def destroy
    super
    # After `super`, which has already built the redirect — cookie changes still
    # ride the response.
    cookies.delete(:player_token)
  end
end
