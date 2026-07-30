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
    scope = user_signed_in? ? current_user.attempts : Attempt.where(player_token: current_player_token)
    scope.distinct.pluck(:puzzle_id).to_set
  end
end
