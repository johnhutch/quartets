# Per-puzzle analytics, computed straight off the recorded attempts — no rollup
# table (revisit only if aggregation gets slow at scale). Pure value object so
# it's trivial to test and reuse. Feed it a puzzle's attempts.
class PuzzleStats
  def initialize(attempts)
    @attempts = attempts.to_a
  end

  def total_attempts
    @attempts.size
  end

  def solved_count
    @attempts.count(&:solved?)
  end

  # Fraction 0.0–1.0; the view turns it into a percentage.
  def solve_rate
    return 0.0 if total_attempts.zero?

    solved_count.fdiv(total_attempts)
  end

  # Every mistake bucket present (0..MAX), even the empty ones, so the view can
  # draw a stable distribution without holes.
  def mistakes_distribution
    buckets = (0..Puzzle::MAX_MISTAKES).index_with { 0 }
    @attempts.each do |attempt|
      count = attempt.mistakes_count.to_i
      buckets[count] += 1 if buckets.key?(count)
    end
    buckets
  end

  # The four-word combos players wrongly grouped together, most frequent first.
  # A guess is "wrong" when its tiles span more than one true color; order within
  # a guess doesn't matter, so we canonicalize by sorting the words.
  def common_wrong_guesses(limit: 5)
    tally = Hash.new(0)

    @attempts.each do |attempt|
      attempt.guess_log.each do |guess|
        next unless guess.wrong? # a correct group isn't a "wrong guess"

        words = guess.words.sort
        tally[words] += 1 unless words.empty?
      end
    end

    tally.sort_by { |words, count| [-count, words] }
         .first(limit)
         .map { |words, count| { words: words, count: count } }
  end
end
