# Staff-facing alerts (superusers + moderators). Right now: a puzzle got flagged.
# Best-effort like all our mail — no SMTP configured means it just doesn't send.
class AdminMailer < ApplicationMailer
  def puzzle_reported(report)
    @report = report
    @puzzle = report.puzzle

    recipients = User.staff.pluck(:email)
    return if recipients.empty?

    mail(
      to: recipients,
      subject: "Puzzle reported: #{@puzzle.title.presence || 'Untitled'}"
    )
  end
end
