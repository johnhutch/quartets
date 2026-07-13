# Site-wide product funnel over a period (analytics stream B) — distinct players
# who reached each stage, all derived from first-party Events + Attempts (no
# client tracking). "Reached a stage" = a distinct player_token, so re-opens don't
# inflate it. Not a strict same-session join; a clean stage-reach funnel, which is
# the honest read for a dashboard. Pairs with PuzzleStats/PlayerStats.
class FunnelStats
  def initialize(since: 7.days.ago)
    @since = since
  end

  # --- Play funnel: opened → started → finished ---
  def opened
    distinct_players(Event.puzzle_opened)
  end

  def started
    distinct_players(Event.game_started)
  end

  # Every recorded Attempt is a finished play (they're only written at game-over).
  def finished
    Attempt.where(created_at: @since..).distinct.count(:player_token)
  end

  def start_rate
    ratio(started, opened)
  end

  def finish_rate
    ratio(finished, started)
  end

  # --- Create funnel: form opened → published ---
  def authoring_opened
    distinct_players(Event.authoring_opened)
  end

  def published
    Puzzle.where(status: :published, created_at: @since..).count
  end

  private

  def distinct_players(scope)
    scope.where(occurred_at: @since..).distinct.count(:player_token)
  end

  def ratio(numerator, denominator)
    return 0.0 if denominator.zero?

    numerator.fdiv(denominator)
  end
end
