class Puzzle < ApplicationRecord
  # NYT rule: four mistakes and you're done. Lives here as the one source of
  # truth — Attempt and the game UI both read it.
  MAX_MISTAKES = 4

  GROUPS_PER_PUZZLE = 4

  # user_id column exists for forward-compat; the belongs_to lands when Devise
  # shows up in Phase 1. Don't reference .user until then.

  has_many :groups, -> { order(:position) }, dependent: :destroy, inverse_of: :puzzle
  has_many :attempts, dependent: :destroy
  accepts_nested_attributes_for :groups

  enum :status, { draft: 0, published: 1 }, default: :draft

  # Auto-generates an unguessable token on create; the unique index backs it.
  has_secure_token :share_token

  validates :title, presence: true

  # The full 4×4 structure is only enforced on publish. Drafts auto-save
  # half-finished, so they stay deliberately lenient.
  validate :complete_structure, if: :published?

  private

  def complete_structure
    unless groups.size == GROUPS_PER_PUZZLE
      errors.add(:groups, "must have exactly #{GROUPS_PER_PUZZLE}")
    end

    colors = groups.map(&:color).compact
    unless colors.uniq.sort == Group.colors.keys.sort
      errors.add(:groups, "must use all four distinct colors")
    end
  end
end
