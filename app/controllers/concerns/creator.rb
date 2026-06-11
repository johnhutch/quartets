# Anonymous, login-free ownership for puzzle *authors* — the create-side mirror
# of AnonymousPlayer (ADR-0005). A logged-out author's puzzles ride a signed,
# permanent creator_token cookie so they can revisit, edit, and publish their own
# work on the same device. Signing in/up claims them (see ClaimsPuzzles).
module Creator
  extend ActiveSupport::Concern

  included do
    helper_method :current_creator_token
  end

  private

  def ensure_creator_token
    cookies.signed.permanent[:creator_token] ||= SecureRandom.uuid
  end

  def current_creator_token
    cookies.signed[:creator_token]
  end

  # The puzzles owned by whoever is making this request: by account if signed in,
  # otherwise by the creator_token cookie. Scopes every owner-facing action.
  def owned_puzzles
    if user_signed_in?
      current_user.puzzles
    else
      Puzzle.where(creator_token: current_creator_token)
    end
  end
end
