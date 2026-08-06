# A first-party analytics event (stream B). Two families now:
#
#   - the *play funnel* — puzzle_opened / game_started / authoring_opened, keyed
#     by the anonymous player_token (mirrors Attempt), read by FunnelStats
#   - *session health* — signed_in / signed_in_remembered, keyed by user, written
#     by the Warden hook in config/initializers/session_events.rb and read by
#     SessionStats
#
# Recorded best-effort — a missed event never blocks the player.
class Event < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :puzzle, optional: true

  # The funnel signals: puzzle_opened (viewed a play page) and authoring_opened
  # (opened the create form) are server-side one-liners; game_started is the one
  # client beacon (nothing else hits the server between open and game-over).
  #
  # The sign-in pair splits one authentication two ways: signed_in means somebody
  # typed a password, signed_in_remembered means the remember cookie carried them
  # in. The *ratio* is the measurement — see SessionStats.
  enum :event_type, { game_started: 0, puzzle_opened: 1, authoring_opened: 2,
                      signed_in: 3, signed_in_remembered: 4 }

  # The sign-in family, which is keyed by user instead of by player. Listing this
  # side rather than the play funnel is deliberate: it's the small, closed one, so
  # a *new* play event type requires a token by default. That's the safe direction
  # — a token that was never captured can't be backfilled.
  USER_KEYED_TYPES = %w[signed_in signed_in_remembered].freeze

  # So a fresh event is well-formed without the caller stamping the time (the
  # column is NOT NULL, so the default is the guarantee — no presence check needed).
  attribute :occurred_at, default: -> { Time.current }

  validates :event_type, presence: true
  # Sign-in events legitimately have no player_token: Devise's own pages don't
  # include AnonymousPlayer, so someone who signs up before ever opening a puzzle
  # has no cookie to read. Everything else is counted per distinct player, where a
  # row without a token is useless data rather than a partial one.
  validates :player_token, presence: true, unless: :user_keyed?

  def user_keyed?
    USER_KEYED_TYPES.include?(event_type)
  end
end
