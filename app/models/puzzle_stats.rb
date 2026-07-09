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

  # Median wall-clock solve, from solved attempts that carry a duration (attempts
  # recorded before timing shipped have none). Nil when there's no data.
  def median_solve_ms
    times = solve_times
    return nil if times.empty?

    mid = times.size / 2
    times.size.odd? ? times[mid] : (times[mid - 1] + times[mid]) / 2
  end

  def fastest_solve_ms
    solve_times.first
  end

  # Clean solves — won without a single wrong guess.
  def flawless_count
    @attempts.count { |a| a.solved? && a.mistakes_count.to_i.zero? }
  end

  # Cumulative trophy tallies earned on this puzzle, same semantics as the
  # dashboard trophy case (ADR-0011): a reverse rainbow also counts as a
  # purple-first and a perfect.
  def trophy_counts
    levels = Attempt.achievements
    PlayerStats::TIERS.index_with do |tier|
      floor = levels.fetch(tier.to_s)
      @attempts.count { |a| a.achievement && levels.fetch(a.achievement) >= floor }
    end
  end

  # Complete solve orders (all four groups cracked), most frequent first — which
  # paths players actually take through the puzzle.
  def common_solve_orders(limit: 3)
    tally = Hash.new(0)

    @attempts.select(&:solved?).each do |attempt|
      order = attempt.solved_colors
      tally[order] += 1 if order.size == 4
    end

    tally.sort_by { |order, count| [-count, order] }
         .first(limit)
         .map { |order, count| { colors: order, count: count } }
  end

  # The four-word combos players wrongly grouped together, most frequent first.
  # A guess is "wrong" when its tiles span more than one true color; order within
  # a guess doesn't matter, so we canonicalize by sorting the words. Each word
  # keeps its true category color (the colors come from the puzzle, so they're
  # identical across attempts) — the view renders them as color-coded chips.
  def common_wrong_guesses(limit: 5)
    tally = Hash.new(0)
    tiles = {}

    @attempts.each do |attempt|
      attempt.guess_log.each do |guess|
        next unless guess.wrong? # a correct group isn't a "wrong guess"

        pairs = guess.words.zip(guess.colors).sort
        next if pairs.empty?

        words = pairs.map(&:first)
        tally[words] += 1
        tiles[words] ||= pairs.map { |word, color| { word: word, color: color } }
      end
    end

    tally.sort_by { |words, count| [-count, words] }
         .first(limit)
         .map { |words, count| { tiles: tiles[words], count: count } }
  end

  private

  def solve_times
    @solve_times ||= @attempts.select(&:solved?).filter_map(&:duration_ms).sort
  end
end
