class Attempt < ApplicationRecord
  belongs_to :puzzle
  # Optional: anonymous plays carry only a player_token (ADR-0005). A logged-in
  # play is also attributed to the account, which caps it at one per puzzle and
  # powers the "already played" result view (ADR-0009).
  belongs_to :user, optional: true

  # Defaults so a fresh attempt is well-formed without the caller spelling it out.
  attribute :solved, default: false
  attribute :mistakes_count, default: 0
  # Ordered guess log; each entry is the 4 picked words + the true color of each.
  # The emoji cube and "common mistakes" both derive from this.
  attribute :guesses, default: -> { [] }

  validates :player_token, presence: true
  validates :mistakes_count,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: Puzzle::MAX_MISTAKES
            }

  # NYT model: out of mistakes and you didn't solve it.
  def lost?
    !solved? && mistakes_count.to_i >= Puzzle::MAX_MISTAKES
  end

  def finished?
    solved? || lost?
  end
end
