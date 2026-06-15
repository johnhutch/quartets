# Mixed into anything that can carry tags (puzzles today; other models later).
# Tags are global, canonical rows; taggings are the polymorphic join.
module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :taggable, dependent: :destroy
    has_many :tags, through: :taggings
  end

  # Accepts an array of raw names (or a comma/newline string); normalizes +
  # find-or-creates each and replaces the set. Blanks/dupes drop out.
  def tag_names=(value)
    names = value.is_a?(Array) ? value : value.to_s.split(/[,\n]/)
    self.tags = names.filter_map { |n| Tag.for_name(n) }.uniq
  end

  def tag_names
    tags.map(&:name)
  end
end
