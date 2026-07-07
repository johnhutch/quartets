# The puzzles tab: every puzzle in the system, every author, with the same
# owner-grade action rows the dashboard has. The row actions hit the plain
# /puzzles routes — PuzzlesController#set_puzzle waves superusers through.
class Admin::PuzzlesController < Admin::BaseController
  def index
    @puzzles = paginate(Puzzle.includes(:user).order(updated_at: :desc))
  end
end
