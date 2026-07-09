class Puzzle < ApplicationRecord
  # NYT rule: four mistakes and you're done. Lives here as the one source of
  # truth — Attempt and the game UI both read it.
  MAX_MISTAKES = 4

  GROUPS_PER_PUZZLE = 4

  # Short share/discovery blurb — sized to fit a Bluesky post alongside the URL.
  DESCRIPTION_LIMIT = 200

  # Optional: a logged-out author owns puzzles through the signed creator_token
  # cookie instead (ADR-0005). Signing in/up claims them onto the account.
  belongs_to :user, optional: true

  include Taggable

  has_many :groups, -> { order(:position) }, dependent: :destroy, inverse_of: :puzzle
  has_many :attempts, dependent: :destroy
  has_many :events, dependent: :destroy
  accepts_nested_attributes_for :groups

  # Visibility, not lifecycle (ADR-0008). `unlisted` (default) = not on the site
  # or in search, but playable by anyone with the link once it's `complete?`.
  # `published` = listed + indexable. Completeness is derived (see #complete?),
  # never stored. ("unlisted" also dodges the Ruby `private`/`Module#private`
  # collision a "private" enum value would have hit.)
  enum :status, { unlisted: 0, published: 1 }, default: :unlisted

  # Hand-picked for the homepage rotation. Curated, not "everything published."
  scope :featured, -> { where(featured: true) }

  # Soft delete (ADR): deleting a *played* puzzle would vaporize every player's
  # attempts — and with them their trophies and stats. So a played puzzle is
  # tombstoned (deleted_at set) instead of destroyed; unplayed ones still hard
  # delete (see PuzzlesController#destroy). The default scope hides tombstones
  # from every surface at once (play-by-token included → 404); admin reaches them
  # through with_deleted/only_deleted.
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :only_deleted, -> { with_deleted.where.not(deleted_at: nil) }

  def soft_delete!
    update_column(:deleted_at, Time.current) # skip validations — a draft can't publish-validate
  end

  def restore!
    update_column(:deleted_at, nil)
  end

  def deleted?
    deleted_at.present?
  end

  # Everything NOT owned by this requester — by account when signed in, else by
  # the anonymous creator_token cookie (mirrors Creator#owns?). Owners can't
  # play their own puzzles (ADR-0015), so play surfaces filter them out here.
  # IS DISTINCT FROM keeps it NULL-safe: plain `!=` would also drop anonymous
  # puzzles (NULL != x is NULL, not true).
  scope :not_owned_by, ->(user:, creator_token:) do
    if user
      where("puzzles.user_id IS DISTINCT FROM ?", user.id)
    elsif creator_token
      where("puzzles.creator_token IS DISTINCT FROM ?", creator_token)
    else
      all
    end
  end

  # Auto-generates an unguessable token on create; the unique index backs it.
  has_secure_token :share_token

  # Everything is only enforced on publish — including the title. The authoring
  # form is answers-first with the title at the bottom, so a half-typed draft
  # routinely has groups but no title yet. Drafts auto-save in that state, so
  # they stay deliberately lenient; publish is where the rules bite.
  # Optional everywhere (never a publish gate); just capped so it stays a blurb.
  validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_blank: true

  validates :title, presence: true, if: :published?
  validate :complete_structure, if: :published?
  validate :no_duplicate_answers, if: :published?

  # The byline name every display surface uses: the owner's account-wide
  # display_name when set (renaming there renames every byline at once), else
  # the puzzle's own free-text author_name (the whole story for anonymous work).
  def author_display_name
    user&.display_name.presence || author_name
  end

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

  # Sixteen answers means sixteen *different* answers. The game keys tiles by
  # their word text (see game_controller), so a repeat — across groups or within
  # one — is unplayable. Case/whitespace don't make words different.
  def no_duplicate_answers
    words = groups.reject(&:marked_for_destruction?).flat_map(&:filled_words).map(&:downcase)
    dupes = words.tally.select { |_, count| count > 1 }.keys
    errors.add(:groups, "use the same answer more than once: #{dupes.join(', ')}") if dupes.any?
  end
end
