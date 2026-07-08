# The public front door — a launchpad, not a play surface. "What are you here to
# do?": play someone's puzzle or make your own (no login for either). Surfaces a
# random handful of published puzzles so there's real content to dive into, not
# just a pitch. Still mints the anonymous player cookie like the play pages.
class HomeController < ApplicationController
  include AnonymousPlayer
  include Creator # for the strip's not-mine filter (you can't play your own)

  STRIP_SIZE = 5

  def show
    # Themed (specialized) quartets ride along flagged — the visible THEMED chip
    # lets a stranger dodge or chase them, which replaced ADR-0010's outright
    # exclusion from the strip. Your own puzzles are out: you can't play them
    # (ADR-0015), so a jump-in row would just dead-end on a revealed board.
    @puzzles = Puzzle.published.includes(:user, :tags)
                     .not_owned_by(user: current_user, creator_token: current_creator_token)
                     .order(Arel.sql("RANDOM()")).limit(STRIP_SIZE)
    # Same "✓ Played" flag as the archive list (ADR-0009): by account when
    # signed in; anonymous visitors just see the plain list.
    @completed_ids = user_signed_in? ? current_user.attempts.distinct.pluck(:puzzle_id).to_set : Set.new
    # Same vote aggregates as the archive rows, one grouped query.
    @rating_summaries = RatingSummary.for(@puzzles)
  end
end
