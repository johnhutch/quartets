# Public, login-free play. Everything here is open to the internet. The index
# lists only published puzzles; an individual board is playable as soon as it's
# complete, listed or not (ADR-0008) — "published" only controls visibility.
class PlayController < ApplicationController
  include AnonymousPlayer
  include Creator # for owns? — the owner gets a share prompt on their own puzzle

  def index
    # "Hide my quartets" is on by default — the archive is for discovering other
    # people's work. Only offered to a viewer who actually owns something here;
    # for everyone else there's nothing to hide and no toggle.
    mine = owned_puzzle_ids & Puzzle.published.ids
    @owns_published = mine.any?
    @hide_mine = @owns_published && params[:mine] != "show"

    scope = Puzzle.published.order(created_at: :desc)
    scope = scope.where.not(id: mine) if @hide_mine
    @puzzles = scope

    # Which of these the signed-in player has already finished, for the badge.
    @completed_ids = user_signed_in? ? current_user.attempts.distinct.pluck(:puzzle_id).to_set : Set.new
  end

  def show
    @puzzle = Puzzle.find_by(share_token: params[:share_token])

    # The play gate (ADR-0008): a complete puzzle plays for anyone with the link
    # (published or just unlisted); an incomplete one effectively doesn't exist —
    # its owner is bounced to the editor, everyone else (and unknown tokens) 404.
    case Playability.new(@puzzle, owner: @puzzle && owns?(@puzzle)).status
    when :editable then return redirect_to(edit_puzzle_path(@puzzle))
    when :missing  then return head(:not_found)
    end

    # One play per non-owner (ADR-0009, ADR-0012): once they've finished a puzzle
    # that isn't their own, show the reconstructed finished board instead of a
    # fresh one. Owners are never gated (they replay to test). Logged-in players
    # are keyed by account; anonymous players by their player_token (best-effort —
    # clearing the cookie still lets a stranger replay, which is fine).
    @my_attempt = finished_attempt unless owns?(@puzzle)
  end

  private

  def finished_attempt
    if user_signed_in?
      current_user.attempts.find_by(puzzle: @puzzle)
    else
      @puzzle.attempts.where(player_token: current_player_token).order(created_at: :desc).first
    end
  end
end
