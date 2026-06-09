# The public front door. Drops a visitor straight into a random featured puzzle —
# no login, no clicks. Re-rolled on every load. If nothing's featured, the view
# falls back to a friendly empty state.
class HomeController < ApplicationController
  include AnonymousPlayer

  def show
    @puzzle = Puzzle.featured.published.order(Arel.sql("RANDOM()")).first
  end
end
