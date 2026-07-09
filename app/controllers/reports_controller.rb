# A player flagging a puzzle for staff review. Public and login-free (anonymous
# reporters carry the player token), deduped one-per-reporter, and it emails staff
# on a genuinely new flag so nothing sits unnoticed.
class ReportsController < ApplicationController
  include AnonymousPlayer

  # Report abuse is itself an abuse vector — cap it.
  rate_limit to: 10, within: 1.hour, only: :create, store: RATE_LIMIT_STORE

  def create
    puzzle = Puzzle.find_by(share_token: params[:share_token])
    return head :not_found unless puzzle

    report = puzzle.reports.find_or_create_by(reporter_token: current_player_token) do |r|
      r.user = current_user
      r.reason = params[:reason].to_s.strip.presence
    end

    # Only alert staff on a genuinely new flag (a repeat returns the existing one).
    AdminMailer.puzzle_reported(report).deliver_later if report.previously_new_record?

    redirect_to play_path(puzzle.share_token), notice: "Thanks — we've flagged this for review."
  end
end
