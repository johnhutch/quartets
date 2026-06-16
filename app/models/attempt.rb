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

  # Trophy tier a flawless win earned (ADR-0011); nil = none. Ordered so cumulative
  # counts are `achievement >= n` (reverse rainbow counts toward all three).
  enum :achievement, { perfect: 1, purple_first: 2, reverse_rainbow: 3 }

  before_create { self.achievement = earned_achievement }

  validates :player_token, presence: true
  validates :mistakes_count,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: Puzzle::MAX_MISTAKES
            }

  # Attempts at the given tier or better (e.g. a reverse rainbow is also a perfect).
  scope :at_least, ->(tier) { where(achievement: achievements.fetch(tier.to_s)..) }

  # The recorded guesses as Guess value objects (the raw jsonb stays on #guesses).
  def guess_log
    guesses.map { |raw| Guess.new(raw) }
  end

  # The colors solved, in the order they were cracked (the solve order). Drives the
  # trophy tier and the reconstructed game-over board on revisit.
  def solved_colors
    guess_log.select(&:correct?).map(&:solved_color)
  end

  # The tier this attempt earns: only a flawless win (all four solved, no mistakes)
  # scores, and the tier is the solve order — purple is hardest, so reverse rainbow
  # is purple→blue→green→yellow.
  def earned_achievement
    return nil unless solved? && mistakes_count.to_i.zero?

    order = solved_colors
    return :reverse_rainbow if order == %w[purple blue green yellow]
    return :purple_first if order.first == "purple"

    :perfect
  end

  # Cumulative trophies this attempt earned, weakest → strongest (a reverse rainbow
  # is also a purple-first and a perfect). Empty unless it scored.
  def earned_tiers
    tier = earned_achievement
    return [] unless tier

    level = self.class.achievements.fetch(tier.to_s)
    self.class.achievements.select { |_, v| v <= level }.keys.map(&:to_sym)
  end

  # Which quip pool fits the outcome: the earned tier, else a flawed win, else a loss.
  def quip_bucket
    earned_achievement || (solved? ? :mistakes : :loss)
  end

  # NYT model: out of mistakes and you didn't solve it.
  def lost?
    !solved? && mistakes_count.to_i >= Puzzle::MAX_MISTAKES
  end

  def finished?
    solved? || lost?
  end
end
