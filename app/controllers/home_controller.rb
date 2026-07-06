# The public front door — a launchpad, not a play surface. "What are you here to
# do?": play someone's puzzle or make your own (no login for either). Surfaces a
# random handful of published puzzles so there's real content to dive into, not
# just a pitch. Still mints the anonymous player cookie like the play pages.
class HomeController < ApplicationController
  include AnonymousPlayer

  STRIP_SIZE = 5

  def show
    @puzzles = Puzzle.published.order(Arel.sql("RANDOM()")).limit(STRIP_SIZE)
  end
end
