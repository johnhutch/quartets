# A play-funnel event (analytics stream B). Today the only writer is the
# `game_started` beacon (EventsController) — the signal that a player actually
# began a game, which lets us derive started→finished funnels and abandons later
# without mutating Attempt. Keyed by the anonymous player_token (mirrors Attempt);
# user and puzzle are optional so the enum can grow to non-play events. Recorded
# best-effort — a missed event never blocks the player.
class Event < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :puzzle, optional: true

  # Room to grow: puzzle_opened / authoring_opened are server-side one-liners the
  # analytics plan adds later; game_started is the one client beacon.
  enum :event_type, { game_started: 0 }

  # So a fresh event is well-formed without the caller stamping the time (the
  # column is NOT NULL, so the default is the guarantee — no presence check needed).
  attribute :occurred_at, default: -> { Time.current }

  validates :event_type, presence: true
  validates :player_token, presence: true
end
