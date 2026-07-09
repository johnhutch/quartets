# The puzzles tab: every puzzle in the system, every author, with the same
# owner-grade action rows the dashboard has. The row actions hit the plain
# /puzzles routes — PuzzlesController#set_puzzle waves superusers through.
class Admin::PuzzlesController < Admin::BaseController
  def index
    # includes(:groups) keeps complete? off the N+1 path; with_deleted so admin
    # sees tombstoned puzzles too, flagged + restorable.
    @puzzles = paginate(Puzzle.with_deleted.includes(:user, :groups).order(updated_at: :desc))
    # Funnel numbers (starts vs attempts, first-group time) — superuser-only
    # signal, so it's computed here and passed to the shared row explicitly.
    @engagement = EngagementStats.for(@puzzles)
    @play_counts = play_counts_for(@puzzles)
  end
end
