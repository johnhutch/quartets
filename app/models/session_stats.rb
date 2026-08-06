# Session health over a window (analytics stream B) — how people are getting into
# their accounts, and how often the site makes them type a password again.
#
# The signal is the *split*, not the totals. Riding the remember cookie is the
# healthy path; typing a password means the previous session didn't survive. So a
# password share that climbs is the site logging people out, which is exactly the
# thing that was invisible before: trackable's sign_in_count counts sign-ins
# without saying what caused them, so a user who gets dumped weekly and a user who
# simply visits weekly look identical.
#
# Reads Event rows written by the Warden hook in
# config/initializers/session_events.rb. Pairs with FunnelStats/TrafficStats.
class SessionStats
  def initialize(since: 30.days.ago)
    @since = since
  end

  def password_sign_ins
    @password_sign_ins ||= count(Event.signed_in)
  end

  def remembered_sign_ins
    @remembered_sign_ins ||= count(Event.signed_in_remembered)
  end

  # Deliberately outside every ratio below. A signup is a new account, not a
  # session that failed to last — folding it into password_sign_ins made the
  # re-login rate climb with new-user growth, so a good launch week read as a
  # session-persistence regression. Reported on its own so the number still has
  # somewhere to be seen.
  def signups
    @signups ||= count(Event.signed_up)
  end

  def total_sign_ins
    password_sign_ins + remembered_sign_ins
  end

  # Share of all sign-ins that made somebody type a password. The headline number:
  # high means sessions aren't lasting.
  def re_login_rate
    return 0.0 if total_sign_ins.zero?

    password_sign_ins.fdiv(total_sign_ins)
  end

  # Median gap, in days, between consecutive password sign-ins by the same
  # account. Answers "how long does a login actually last?" directly, where the
  # rate above only says how often it fails.
  #
  # nil when nobody in the window signed in with a password twice — there's no gap
  # to measure. That's the healthy case, and reporting it as 0 would invert the
  # meaning of the whole number.
  def median_days_between_password_sign_ins
    EngagementStats.median(password_sign_in_gaps_in_days)
  end

  private

  def count(scope)
    scope.where(occurred_at: @since..).count
  end

  # Every consecutive pair of password sign-ins by the same account, as days.
  # An account with only one has no predecessor and contributes nothing —
  # `each_cons(2)` over a single element is empty, which is why there's no guard.
  #
  # Gaps are measured strictly inside the window, so a shorter window can only
  # report shorter gaps. Read it alongside the raw counts, not on its own.
  def password_sign_in_gaps_in_days
    Event.signed_in.where(occurred_at: @since..).where.not(user_id: nil)
         .order(:user_id, :occurred_at).pluck(:user_id, :occurred_at)
         .group_by(&:first)
         .flat_map { |_, rows| rows.map(&:last).each_cons(2).map { |a, b| (b - a) / 1.day } }
  end
end
