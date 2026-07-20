# The save-game for an in-progress play. Finished plays are Attempts; this is
# the board mid-flight — the server-derived guess log plus the play clock — so
# leaving a puzzle and coming back resumes instead of resetting. Keyed by
# account when there is one (survives devices), else by the anonymous
# player_token (survives as long as the cookie does). Spent (deleted) the
# moment the finished play records.
class PlayState < ApplicationRecord
  belongs_to :puzzle
  # Anonymous saves carry only the player_token, same split as Attempt.
  belongs_to :user, optional: true

  attribute :guesses, default: -> { [] }

  # How long an *anonymous* save survives without a new guess before the
  # recurring prune (config/recurring.yml) reclaims it. Anonymous rows are the
  # unbounded ones — every drive-by visitor who makes a guess mints one — and a
  # month idle means the game is abandoned (or the cookie's gone and the row is
  # unreachable anyway). Account saves are exempt: resuming across sessions and
  # devices is the promise to logged-in players, and they're bounded at one row
  # per user per puzzle.
  ANONYMOUS_TTL = 30.days

  # Idle anonymous saves, ripe for pruning. Idleness runs from the last save
  # (updated_at — every guess bumps it), not from when the game began.
  scope :stale, -> { where(user_id: nil).where(updated_at: ...ANONYMOUS_TTL.ago) }

  validates :player_token, presence: true
end
