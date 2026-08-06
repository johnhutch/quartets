# Anonymous, login-free ownership for puzzle *authors* — the create-side mirror
# of AnonymousPlayer (ADR-0005). A logged-out author's puzzles ride a signed
# creator_token cookie so they can revisit, edit, and publish their own work on
# the same device. Signing in/up claims them (see AnonymousClaim).
module Creator
  extend ActiveSupport::Concern
  include IdentityCookies

  included do
    helper_method :current_creator_token, :owns?
    before_action :refresh_creator_token
  end

  private

  # Minting stays PuzzlesController's job (`before_action :ensure_creator_token,
  # unless: :user_signed_in?`) — no reason to hand a creator identity to someone
  # who has only ever played. But *refreshing* has to happen wherever Creator is
  # included, which is the play and home surfaces too.
  #
  # Without this the cookie only slid on authoring pages, so an author who
  # published a quartet, shared the link, and then did the normal thing — visit
  # /p/:share_token and /play to watch it get played — never re-stamped it. Three
  # months on, `owns?` goes false and edit/unpublish/delete/stats all 404 on a
  # live puzzle, with no way back: `puzzles.user_id` is nil and the cookie was the
  # only key, so even signing up can't claim it. That's a public listing nobody
  # can take down, which is a long way past the "lost drafts" this was meant to
  # cost.
  def refresh_creator_token
    return if user_signed_in? || current_creator_token.blank?

    ensure_creator_token
  end

  def ensure_creator_token
    @current_creator_token = write_identity_cookie(:creator_token,
                                                   expires: identity_lifespan.from_now)
  end

  def current_creator_token
    @current_creator_token ||= cookies.signed[:creator_token]
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
