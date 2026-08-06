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

  # Same three months as the play token and the login (ADR-0025) — no cookie on
  # this site outlives that. Only ever runs signed out (PuzzlesController gates it
  # on `unless: :user_signed_in?`), so unlike the play token there's no login
  # state to mirror: one rule, sliding on each visit to an authoring page.
  #
  # An anonymous author away longer than that loses the device-side claim on
  # unpublished work. That's the deal the short cookie buys, and signing up is the
  # answer — AnonymousClaim sweeps the drafts onto the account the moment you do.
  def ensure_creator_token
    cookies.signed[:creator_token] = {
      value: current_creator_token || SecureRandom.uuid,
      expires: Devise.remember_for.from_now
    }
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
