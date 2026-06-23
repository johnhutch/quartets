# Anonymous, login-free ownership for puzzle *authors* — the create-side mirror
# of AnonymousPlayer (ADR-0005). A logged-out author's puzzles ride a signed,
# permanent creator_token cookie so they can revisit, edit, and publish their own
# work on the same device. Signing in/up claims them (see ClaimsPuzzles).
module Creator
  extend ActiveSupport::Concern

  included do
    helper_method :current_creator_token, :owns?
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

  # The ids of puzzles this requester owns, safe to call without a token. Unlike
  # owned_puzzles, this never falls back to `creator_token: nil` (which would
  # match every account-owned puzzle) — a tokenless visitor simply owns nothing.
  def owned_puzzle_ids
    if user_signed_in?
      current_user.puzzle_ids
    elsif current_creator_token.present?
      Puzzle.where(creator_token: current_creator_token).ids
    else
      []
    end
  end

  # Does the current requester own this puzzle? Lets public surfaces (e.g. the
  # play page) show owner-only affordances like the share prompt.
  def owns?(puzzle)
    if user_signed_in?
      puzzle.user_id == current_user.id
    else
      puzzle.creator_token.present? && puzzle.creator_token == current_creator_token
    end
  end
end
