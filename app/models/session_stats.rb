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
    gaps = password_sign_in_gaps_in_days
    return nil if gaps.empty?

    median(gaps)
  end

  private

  def count(scope)
    scope.where(occurred_at: @since..).count
  end

  # One pass with a window function: LAG gives each sign-in its account's previous
  # one, so the gaps fall out as a single column. The first sign-in per account has
  # no predecessor and comes back NULL — dropped, not zeroed.
  #
  # Gaps are measured strictly inside the window, so a shorter window can only
  # report shorter gaps. Read it alongside the raw counts, not on its own.
  def password_sign_in_gaps_in_days
    seconds = Event.connection.select_values(
      Event.sanitize_sql_array([ <<~SQL.squish, Event.event_types[:signed_in], @since ])
        SELECT EXTRACT(EPOCH FROM (occurred_at - LAG(occurred_at)
                 OVER (PARTITION BY user_id ORDER BY occurred_at)))
        FROM events
        WHERE event_type = ? AND user_id IS NOT NULL AND occurred_at >= ?
      SQL
    )
    seconds.compact.map { |s| s.to_f / 1.day }
  end

  def median(values)
    sorted = values.sort
    mid = sorted.size / 2
    return sorted[mid] if sorted.size.odd?

    (sorted[mid - 1] + sorted[mid]) / 2.0
  end
end
