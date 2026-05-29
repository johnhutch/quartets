class Group < ApplicationRecord
  WORDS_PER_GROUP = 4

  belongs_to :puzzle, inverse_of: :groups

  enum :color, { blue: 0, green: 1, yellow: 2, purple: 3 }

  # jsonb column; default to an empty array so the form/importer never juggle nil.
  attribute :words, default: -> { [] }

  validates :color, presence: true, uniqueness: { scope: :puzzle_id }

  # Like the puzzle's structural rules, contents are only required on publish —
  # a draft group can be blank while the author is still typing.
  validates :description, presence: true, if: :parent_published?
  validate :exactly_four_words, if: :parent_published?

  # Words minus the blanks the form may leave behind.
  def filled_words
    Array(words).map { |w| w.to_s.strip }.reject(&:blank?)
  end

  private

  def parent_published?
    puzzle&.published?
  end

  def exactly_four_words
    return if filled_words.size == WORDS_PER_GROUP

    errors.add(:words, "must have exactly #{WORDS_PER_GROUP}")
  end
end
