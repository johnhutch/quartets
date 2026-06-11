# Claim-on-auth (ADR-0005). The instant a request is authenticated and the
# creator_token cookie still owns puzzles, reassign them to the account and clear
# the cookie. Runs site-wide so it fires after signup, login, or a remembered
# session — wherever the user first shows up authenticated.
module ClaimsPuzzles
  extend ActiveSupport::Concern

  included do
    before_action :claim_anonymous_puzzles
  end

  private

  def claim_anonymous_puzzles
    return unless user_signed_in?

    token = cookies.signed[:creator_token]
    return if token.blank?

    Puzzle.where(creator_token: token)
          .update_all(user_id: current_user.id, creator_token: nil)
    cookies.delete(:creator_token)
  end
end
