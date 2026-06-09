class Puzzle < ApplicationRecord
  # NYT rule: four mistakes and you're done. Lives here as the one source of
  # truth — Attempt and the game UI both read it.
  MAX_MISTAKES = 4

  GROUPS_PER_PUZZLE = 4

  belongs_to :user

  has_many :groups, -> { order(:position) }, dependent: :destroy, inverse_of: :puzzle
  has_many :attempts, dependent: :destroy
  accepts_nested_attributes_for :groups

  enum :status, { draft: 0, published: 1 }, default: :draft

  # Hand-picked for the homepage rotation. Curated, not "everything published."
  scope :featured, -> { where(featured: true) }

  # Auto-generates an unguessable token on create; the unique index backs it.
  has_secure_token :share_token

  # Everything is only enforced on publish — including the title. The authoring
  # form is answers-first with the title at the bottom, so a half-typed draft
  # routinely has groups but no title yet. Drafts auto-save in that state, so
  # they stay deliberately lenient; publish is where the rules bite.
  validates :title, presence: true, if: :published?
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
