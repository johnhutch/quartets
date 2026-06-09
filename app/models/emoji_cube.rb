# Turns an attempt's ordered guesses into the shareable 🟨🟩🟦🟪 grid — one row
# per guess, each square the *true* color of the word picked in that slot. Pure
# value object (no DB); the single source of truth for the cube, server-side and
# in the JSON the game posts back.
class EmojiCube
  SQUARES = {
    "yellow" => "🟨",
    "green"  => "🟩",
    "blue"   => "🟦",
    "purple" => "🟪"
  }.freeze

  # Anything unrecognized degrades to a blank square instead of crashing a share.
  BLANK = "⬜"

  def initialize(guesses)
    @guesses = Array(guesses)
  end

  def rows
    @guesses.map { |guess| row_for(guess) }
  end

  def to_s
    rows.join("\n")
  end

  private

  def row_for(guess)
    colors = guess["colors"] || guess[:colors] || []
    colors.map { |color| SQUARES.fetch(color.to_s, BLANK) }.join
  end
end
