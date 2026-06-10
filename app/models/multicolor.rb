# Bands a string into the four category colors for the brutalist wordmark + big
# headings. The whole header is one ribbon: color switches every 3–6 *letters*
# and carries straight through spaces (so breaks fall mid-word, not on word
# edges). Non-deterministic by default — it re-rolls both the breaks and the
# colors every call, so a header bands a fresh way on every page load. Pass a
# seed: to pin a stable banding (the rare caller inside a cached fragment).
# Pure + testable.
class Multicolor
  COLORS = %w[blue green yellow purple].freeze

  def initialize(text, min_run: 3, max_run: 6, seed: nil)
    @text = text.to_s
    @min_run = min_run
    @max_run = max_run
    @seed = seed
  end

  # => [[substring, color], ...] over the original text (spaces included).
  def segments
    rng     = @seed ? Random.new(@seed) : Random.new
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
end
