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
  # Strictly nested: each stage is the set of players who reached the PRIOR stage
  # AND this one. That's the real funnel definition, and it guarantees the counts
  # can't invert (no >100% conversion) while the three signals accumulate at
  # different rates — e.g. right after opened-capture ships and started has history.
  def opened
    opened_tokens.size
  end

  def started
    started_tokens.size
  end

  def finished
    finished_tokens.size
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

  def opened_tokens
    @opened_tokens ||= tokens(Event.puzzle_opened)
  end

  def started_tokens
    @started_tokens ||= tokens(Event.game_started) & opened_tokens
  end

  # Every recorded Attempt is a finished play (only written at game-over).
  def finished_tokens
    @finished_tokens ||=
      Attempt.where(created_at: @since..).distinct.pluck(:player_token).to_set & started_tokens
  end

  def tokens(event_scope)
    event_scope.where(occurred_at: @since..).distinct.pluck(:player_token).to_set
  end

  def distinct_players(scope)
    scope.where(occurred_at: @since..).distinct.count(:player_token)
  end

  def ratio(numerator, denominator)
    return 0.0 if denominator.zero?

    numerator.fdiv(denominator)
  end
end
