class Group < ApplicationRecord
  WORDS_PER_GROUP = 4

  belongs_to :puzzle, inverse_of: :groups

  enum :color, { blue: 0, green: 1, yellow: 2, purple: 3 }

  # jsonb column; default to an empty array so the form/importer never juggle nil.
  attribute :words, default: -> { [] }

  validates :color, presence: true
  # One group per color, judged against the in-memory sibling set (not the DB):
  # the authoring form's color-swap updates two groups in one nested save, and a
  # DB-backed uniqueness check would 422 every swap against stale colors.
  validate :color_unique_within_puzzle

  # Like the puzzle's structural rules, contents are only required on publish —
  # a draft group can be blank while the author is still typing.
  validates :description, presence: true, if: :parent_published?
  validate :exactly_four_words, if: :parent_published?

  # Words minus the blanks the form may leave behind.
  def filled_words
    Array(words).map { |w| w.to_s.strip }.reject(&:blank?)
  end

  private

  def color_unique_within_puzzle
    return if color.blank? || puzzle.nil?

    siblings = puzzle.groups.reject { |g| g == self || g.marked_for_destruction? }
    errors.add(:color, "has already been taken") if siblings.any? { |g| g.color == color }
  end

  def parent_published?
    puzzle&.published?
  end

  def exactly_four_words
    return if filled_words.size == WORDS_PER_GROUP

    errors.add(:words, "must have exactly #{WORDS_PER_GROUP}")
  end
end
