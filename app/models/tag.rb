class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  # Convenience for the puzzle browse/filter; other taggables would add their own.
  has_many :puzzles, through: :taggings, source: :taggable, source_type: "Puzzle"

  validates :name, presence: true, uniqueness: true

  # Normalize any user input to a canonical hyphen-slug: "Star Wars!" -> "star-wars",
  # "  90s  Music " -> "90s-music", "sci-fi" -> "sci-fi". Returns nil for junk/blank
  # so callers can drop it. This convergence is what fights cold-start divergence
  # ("Star Wars" / "star wars" / "StarWars" all land on the same row).
  def self.normalize(raw)
    raw.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "").presence
  end

  # Find-or-create by normalized name; nil for input that normalizes to nothing.
  # find_or_create_by is select-then-insert, so a concurrent create of the same
  # new tag can still lose the unique-index race — rescue it and re-find rather
  # than 500. (create_or_find_by is no good here: the uniqueness validation
  # short-circuits its insert, so it never sees the RecordNotUnique to recover.)
  def self.for_name(raw)
    name = normalize(raw)
    return unless name

    find_or_create_by(name:)
  rescue ActiveRecord::RecordNotUnique
    find_by(name:)
  end
end
