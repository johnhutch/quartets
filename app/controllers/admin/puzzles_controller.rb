# The puzzles tab: every puzzle in the system, every author, with the same
# owner-grade action rows the dashboard has. The row actions hit the plain
# /puzzles routes — PuzzlesController#set_puzzle waves superusers through.
class Admin::PuzzlesController < Admin::BaseController
  def index
    # includes(:groups) keeps complete? off the N+1 path; with_deleted so admin
    # sees tombstoned puzzles too, flagged + restorable.
    scope = Puzzle.with_deleted.includes(:user, :groups)

    # Flagged puzzles: a top-of-page banner counts them, and ?flagged=1 filters
    # to just those so a moderator can triage without paging through everything.
    flagged_ids = Report.unresolved.distinct.pluck(:puzzle_id)
    @flagged_total = flagged_ids.size
    scope = scope.where(id: flagged_ids) if params[:flagged].present?

    @puzzles = paginate(scope.order(updated_at: :desc))
    # Funnel numbers (starts vs attempts, first-group time) — staff-only signal,
    # so it's computed here and passed to the shared row explicitly.
    @engagement = EngagementStats.for(@puzzles)
    @play_counts = play_counts_for(@puzzles)
    @report_counts = Report.unresolved.where(puzzle_id: @puzzles.map(&:id)).group(:puzzle_id).count
  end

  # Mark a puzzle's flags handled without touching the puzzle — for a report that
  # turned out to be nothing. (A real takedown just deletes/unpublishes instead.)
  def dismiss_reports
    puzzle = Puzzle.with_deleted.find(params[:id])
    puzzle.reports.unresolved.update_all(resolved: true)
    redirect_back fallback_location: admin_puzzles_path, notice: "Reports dismissed."
  end
end
