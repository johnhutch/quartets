# Turns a play's ordered guesses into the shareable 🟨🟩🟦🟪 grid — one row per
# guess, each square the *true* color of the word picked in that slot. Pure value
# object (no DB); consumes Guesses (the jsonb shape lives in Guess, not here).
class EmojiCube
  SQUARES = {
    "yellow" => "🟨",
    "green"  => "🟩",
    "blue"   => "🟦",
    "purple" => "🟪"
  }.freeze

  # Anything unrecognized degrades to a blank square instead of crashing a share.
  BLANK = "⬜"

  # `guesses` is an Array<Guess> (e.g. `attempt.guess_log`).
  def initialize(guesses)
    @guesses = Array(guesses)
  end

  def rows
    @guesses.map { |guess| guess.colors.map { |color| SQUARES.fetch(color, BLANK) }.join }
  end

  def to_s
    rows.join("\n")
  end
end
