# Per-puzzle report triage: the flag badge on the puzzles tab lands here. One
# page shows the puzzle compact (groups + meta + action links), the open reports
# each with a resolve-and/or-comment form, and the resolved ones collapsed to a
# one-line fold-out. Staff-wide, like the rest of puzzle moderation.
class Admin::ReportsController < Admin::BaseController
  def index
    @puzzle = Puzzle.with_deleted.includes(:user, :groups).find(params[:puzzle_id])
    reports = @puzzle.reports.includes(:user, :resolved_by, comments: :user)
                     .order(created_at: :desc)
    @open_reports, @resolved_reports = reports.partition { |r| !r.resolved? }
  end

  # One form, two optional fields — a resolution and/or a comment; an empty
  # submit is the only invalid one. Re-resolving restamps (WILLDO → FIXED).
  def update
    report = Report.find(params[:id])
    resolution = params.dig(:report, :resolution).presence
    body = params.dig(:report, :comment).to_s.strip.presence
    triage = admin_puzzle_reports_path(report.puzzle)

    return redirect_to triage, alert: "Pick a resolution or leave a comment." unless resolution || body
    return redirect_to triage, alert: "Unknown resolution." if resolution && !Report.resolutions.key?(resolution)

    report.resolve!(resolution, by: current_user) if resolution
    report.comments.create!(user: current_user, body: body) if body
    redirect_to triage, notice: "Report updated."
  end
end
