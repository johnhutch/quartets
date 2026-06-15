class Puzzle < ApplicationRecord
  # NYT rule: four mistakes and you're done. Lives here as the one source of
  # truth — Attempt and the game UI both read it.
  MAX_MISTAKES = 4

  GROUPS_PER_PUZZLE = 4

  # Optional: a logged-out author owns puzzles through the signed creator_token
  # cookie instead (ADR-0005). Signing in/up claims them onto the account.
  belongs_to :user, optional: true

  has_many :groups, -> { order(:position) }, dependent: :destroy, inverse_of: :puzzle
  has_many :attempts, dependent: :destroy
  accepts_nested_attributes_for :groups

  # Visibility, not lifecycle (ADR-0008). `unlisted` (default) = not on the site
  # or in search, but playable by anyone with the link once it's `complete?`.
  # `published` = listed + indexable. Completeness is derived (see #complete?),
  # never stored. ("unlisted" also dodges the Ruby `private`/`Module#private`
  # collision a "private" enum value would have hit.)
  enum :status, { unlisted: 0, published: 1 }, default: :unlisted

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

  # Fully filled out and ready to publish: a title, all four groups, and every
  # group has its four words + a category. Drives the "Save draft"→"Finish"
  # button label (server-side default; the autosave controller keeps it live).
  def complete?
    title.present? &&
      groups.size == GROUPS_PER_PUZZLE &&
      groups.all? { |g| g.description.present? && g.filled_words.size == Group::WORDS_PER_GROUP }
  end

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
