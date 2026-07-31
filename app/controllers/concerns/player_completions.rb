# Which puzzles this visitor has already finished.
#
# Identity mirrors Attempt itself (and PlayController#finished_attempt): by
# account when signed in, else by the anonymous player_token cookie — so the rule
# holds without a login. Requires AnonymousPlayer for current_player_token.
#
# The two surfaces use it differently, on purpose:
#   - home's jump-in strip drops finished puzzles outright; it exists to hand you
#     something to play, and a finished one dead-ends on the result board
#   - the archive keeps them but sinks them below the unplayed ones under their
#     own heading; it's a catalog, so hiding entries would be lying about what's
#     on the site
module PlayerCompletions
  extend ActiveSupport::Concern

  private

  def completed_puzzle_ids
    my_attempts.distinct.pluck(:puzzle_id).to_set
  end

  # The viewer's own finished attempt per puzzle, keyed by puzzle id — the archive
  # builds each solved card's result grid from it. One query for the whole page.
  # Ordered so that if a token somehow carries two attempts on one puzzle, the
  # newest wins rather than an arbitrary row.
  def my_attempts_by_puzzle(puzzles)
    ids = puzzles.map(&:id)
    return {} if ids.empty?

    my_attempts.where(puzzle_id: ids).order(:created_at).index_by(&:puzzle_id)
  end

  # By account when signed in, else by the anonymous player_token cookie.
  def my_attempts
    user_signed_in? ? current_user.attempts : Attempt.where(player_token: current_player_token)
  end
end
