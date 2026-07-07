# The public front door — a launchpad, not a play surface. "What are you here to
# do?": play someone's puzzle or make your own (no login for either). Surfaces a
# random handful of published puzzles so there's real content to dive into, not
# just a pitch. Still mints the anonymous player cookie like the play pages.
class HomeController < ApplicationController
  include AnonymousPlayer

  STRIP_SIZE = 5

  def show
    # Classic puzzles only — a themed (specialized) quartet needs its niche, so
    # it isn't a fair random jump-in for a stranger. Discovery surfaces will
    # carry those (ADR-0010).
    @puzzles = Puzzle.published.where(specialized: false)
                     .order(Arel.sql("RANDOM()")).limit(STRIP_SIZE)
    # Same "✓ Played" flag as the archive list (ADR-0009): by account when
    # signed in; anonymous visitors just see the plain list.
    @completed_ids = user_signed_in? ? current_user.attempts.distinct.pluck(:puzzle_id).to_set : Set.new
  end
end
