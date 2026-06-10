require "digest"

# Bands a string into the four category colors for the brutalist wordmark + big
# headings. The whole header is one ribbon: color switches every 4–7 *letters*
# and carries straight through spaces (so breaks fall mid-word, not on word
# edges). Deterministic — seeded on the text — so a given header always bands the
# same way, while different headers look different. Pure + testable.
class Multicolor
  COLORS = %w[blue green yellow purple].freeze

  def initialize(text, min_run: 4, max_run: 7)
    @text = text.to_s
    @min_run = min_run
    @max_run = max_run
  end

  # => [[substring, color], ...] over the original text (spaces included).
  def segments
    rng     = Random.new(seed)
    color   = COLORS[rng.rand(COLORS.size)]
    run_len = rng.rand(@min_run..@max_run)
    letters = 0
    out     = []
    buf     = +""

    @text.each_char do |char|
      letter = char.match?(/[[:alpha:]]/)

      if letter && letters >= run_len
        out << [buf, color]
        buf     = +""
        color   = (COLORS - [color])[rng.rand(COLORS.size - 1)]
        run_len = rng.rand(@min_run..@max_run)
        letters = 0
      end

      buf << char
      letters += 1 if letter
    end

    out << [buf, color] unless buf.empty?
    out
  end

  private

  # Stable pseudo-random seed derived from the text itself.
  def seed
    Digest::MD5.hexdigest(@text)[0, 8].to_i(16)
  end
end
