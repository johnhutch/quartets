# One recorded guess from a play: the four words the player grouped and the *true*
# color of each picked tile. The single owner of the guess-log shape — the jsonb
# arrives with string keys from JSON but tests build it with symbols, so this is
# the one place that normalizes both. Correctness is **derived**, not stored: a
# guess is correct when all its tiles share one color (the Connections rule), so
# the cube, the stats, and the trophies all read the same definition.
class Guess
  def initialize(raw)
    @colors = Array(raw["colors"] || raw[:colors]).map(&:to_s)
    @words  = Array(raw["words"] || raw[:words]).map(&:to_s)
    # ms since the game clock started, when present. Absent (nil) on plays
    # recorded before timing shipped.
    @t = (raw["t"] || raw[:t])&.to_i
  end

  attr_reader :colors, :words

  # When this guess was submitted, in ms since the clock started (nil if untimed).
  def elapsed_ms
    @t
  end

  def correct?
    colors.any? && colors.uniq.size == 1
  end

  def wrong?
    colors.uniq.size > 1
  end

  # The group a correct guess found; nil for a wrong (or empty) one.
  def solved_color
    colors.first if correct?
  end
end
