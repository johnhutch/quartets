# Public, login-free play. Everything here is open to the internet. The index
# lists only published puzzles; an individual board is playable as soon as it's
# complete, listed or not (ADR-0008) — "published" only controls visibility.
class PlayController < ApplicationController
  include AnonymousPlayer
  include Creator # for owns? — the owner gets a share prompt on their own puzzle

  def index
    @puzzles = Puzzle.published.order(created_at: :desc)
    # Which of these the signed-in player has already finished, for the badge.
    @completed_ids = user_signed_in? ? current_user.attempts.distinct.pluck(:puzzle_id).to_set : Set.new
  end

  def show
    @puzzle = Puzzle.find_by!(share_token: params[:share_token])

    # Playability gates on completeness, not visibility (ADR-0008): a finished
    # puzzle plays for anyone with the link (published or just unlisted). An
    # incomplete one can't be played — its owner is bounced to the editor to
    # finish it; everyone else gets a 404 (it effectively doesn't exist yet).
    unless @puzzle.complete?
      return redirect_to(edit_puzzle_path(@puzzle)) if owns?(@puzzle)

      return head :not_found
    end

    # One play per logged-in player (ADR-0009): once they've finished a puzzle
    # that isn't their own, show their saved result instead of a fresh board.
    @my_attempt = current_user.attempts.find_by(puzzle: @puzzle) if user_signed_in? && !owns?(@puzzle)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
