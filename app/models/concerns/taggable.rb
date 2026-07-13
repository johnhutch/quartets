# Mixed into anything that can carry tags (puzzles today; other models later).
# Tags are global, canonical rows; taggings are the polymorphic join.
module Taggable
  extend ActiveSupport::Concern

  # A handful of tags keeps discovery meaningful — a puzzle tagged with everything
  # is tagged with nothing.
  TAG_LIMIT = 3

  included do
    has_many :taggings, as: :taggable, dependent: :destroy
    has_many :tags, through: :taggings
    # Resolve + attach tags inside the save transaction (after_save), not during
    # params assignment: otherwise a save that then fails validation still commits
    # the tag change, and failed (public, anonymous) saves spam the global Tag
    # table with junk rows. Buffered here, synced only on a successful save.
    after_save :sync_pending_tags, if: :pending_tags?
    validate :tags_within_limit
  end

  # Buffers raw names (an array, or a comma/newline string); nothing hits the DB
  # until save. Blanks/dupes drop out at sync time.
  def tag_names=(value)
    @pending_tag_names = value.is_a?(Array) ? value : value.to_s.split(/[,\n]/)
  end

  # Reflects the pending assignment before save (so a validation-failed form
  # re-render shows what the author typed), else the persisted tags.
  def tag_names
    return tags.map(&:name) unless pending_tags?

    @pending_tag_names.filter_map { |n| Tag.normalize(n) }.uniq
  end

  private

  def tags_within_limit
    errors.add(:base, "A puzzle can have at most #{TAG_LIMIT} tags.") if tag_names.size > TAG_LIMIT
  end

  def pending_tags?
    !@pending_tag_names.nil?
  end

  def sync_pending_tags
    self.tags = @pending_tag_names.filter_map { |n| Tag.for_name(n) }.uniq
    @pending_tag_names = nil
  end
end
