# The public front door. Drops a visitor straight into a playable puzzle — no
# login, no clicks. Prefers a random featured puzzle; with none featured, falls
# back to a random *unplayed* published puzzle so there's always something to do.
# Cleared the whole board? The view sends them off to make one.
class HomeController < ApplicationController
  include AnonymousPlayer

  def show
    @puzzle = Puzzle.featured.published.order(Arel.sql("RANDOM()")).first ||
              random_unplayed_puzzle
    # Nothing left to show, but published puzzles exist ⇒ they've done them all.
    @cleared_them_all = @puzzle.nil? && Puzzle.published.exists?
  end

  private

  # A random published puzzle the visitor hasn't finished yet — by account when
  # signed in, else by the player_token cookie (mirrors play#index / ADR-0012).
  def random_unplayed_puzzle
    Puzzle.published
          .where.not(id: completed_puzzle_ids)
          .order(Arel.sql("RANDOM()"))
          .first
  end

  def completed_puzzle_ids
    scope = user_signed_in? ? current_user.attempts : Attempt.where(player_token: current_player_token)
    scope.select(:puzzle_id)
  end
end
