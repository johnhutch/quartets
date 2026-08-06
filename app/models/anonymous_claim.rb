# Sweeps everything a visitor did anonymously onto their account, at the moment
# they authenticate. The widened form of ADR-0005's puzzle claim: now that no
# cookie outlives three months, a cookie is a *lease* on your work rather than the
# place it lives, and the account is the only durable home. That also fixes the
# cases a long cookie never could — playing in a private window, or across a
# phone, a laptop, and a desktop.
#
# Two identities feed it, and they behave differently on the way out: the author
# token is spent (the caller deletes it — standing in for an account was its only
# job), while the play token stays, because it keeps stamping new attempts.
class AnonymousClaim
  def initialize(user:, creator_token: nil, player_token: nil)
    @user = user
    @creator_token = creator_token.presence
    @player_token = player_token.presence
  end

  # Which token drives which step, stated once. A transaction that issues no
  # queries emits no BEGIN, so there's nothing to guard against up front.
  def call
    ApplicationRecord.transaction do
      claim_puzzles if @creator_token
      next unless @player_token

      claim_attempts
      claim_play_states
      claim_reports
    end
  end

  private

  # Authoring (ADR-0005). No uniqueness to dodge — a puzzle has exactly one owner.
  def claim_puzzles
    Puzzle.where(creator_token: @creator_token)
          .update_all(user_id: @user.id, creator_token: nil)
  end

  # The one place with a real constraint. ADR-0009 caps a signed-in player at one
  # attempt per puzzle (partial unique index on user_id + puzzle_id) while
  # anonymous play was never capped, so a token can hold several attempts on the
  # same puzzle *and* the account may already hold one. Both collide.
  #
  # So: the earliest anonymous attempt per puzzle, and only for puzzles the
  # account hasn't played — earliest because ADR-0009's rule is that the first
  # recorded play is the one that counts. Leftovers stay anonymous rather than
  # being deleted; they're still real plays in that puzzle's aggregate stats.
  def claim_attempts
    # The DISTINCT ON has to ride inside pluck: a plain `pluck(:id)` after a
    # `select` builds its own SELECT clause and drops it, quietly claiming every
    # duplicate play and colliding on the index.
    ids = Attempt.where(player_token: @player_token, user_id: nil)
                 .where.not(puzzle_id: @user.attempts.select(:puzzle_id))
                 .order(:puzzle_id, :created_at)
                 .pluck(Arel.sql("DISTINCT ON (puzzle_id) id"))

    Attempt.where(id: ids).update_all(user_id: @user.id)
  end

  # Mid-game saves (ADR-0022). Its anonymous index is unique per (puzzle, token),
  # so there's at most one to take per puzzle — only the account's own save can
  # get in the way. PlayController#resumable_state still adopts a save lazily when
  # you open that exact puzzle; this just stops resuming from depending on it.
  def claim_play_states
    PlayState.where(player_token: @player_token, user_id: nil)
             .where.not(puzzle_id: PlayState.where(user_id: @user.id).select(:puzzle_id))
             .update_all(user_id: @user.id)
  end

  # Flags raised anonymously (ADR-0020). The dedup index is on (puzzle_id,
  # reporter_token), which we don't touch, so attaching the account can't collide
  # — it just puts a name to a report staff already had.
  def claim_reports
    Report.where(reporter_token: @player_token, user_id: nil).update_all(user_id: @user.id)
  end
end
