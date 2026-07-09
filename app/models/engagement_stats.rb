# Superuser-only per-puzzle funnel numbers (the admin puzzles tab): distinct
# players who started (the game_started beacon) vs those who recorded an
# attempt — the gap is abandons — plus the median time to crack a first group.
# Shaped like RatingSummary: .for takes the page of puzzles and returns one
# grouped-computation hash keyed by puzzle_id; puzzles with no signal get no
# entry so the view can render-if-present.
class EngagementStats
  def self.for(puzzles)
    ids = puzzles.map(&:id)
    starters = Event.game_started.where(puzzle_id: ids)
                    .distinct.pluck(:puzzle_id, :player_token)
                    .group_by(&:first).transform_values { |pairs| pairs.map(&:last).to_set }
    players  = Attempt.where(puzzle_id: ids)
                      .distinct.pluck(:puzzle_id, :player_token)
                      .group_by(&:first).transform_values { |pairs| pairs.map(&:last).to_set }
    first_group_times = Attempt.where(puzzle_id: ids).pluck(:puzzle_id, :guesses)
                               .group_by(&:first)
                               .transform_values { |pairs| pairs.flat_map { |_, guesses| first_group_ms(guesses) } }

    ids.each_with_object({}) do |id, stats|
      start_tokens = starters[id] || Set.new
      stat = new(
        starts: start_tokens.size,
        abandons: (start_tokens - (players[id] || Set.new)).size,
        median_first_group_ms: median(first_group_times[id] || [])
      )
      stats[id] = stat if stat.any?
    end
  end

  # The elapsed ms of the first correct guess in a raw guess log (nil when the
  # attempt never cracked a group, or predates per-guess timing).
  def self.first_group_ms(raw_guesses)
    guess = Array(raw_guesses).map { |raw| Guess.new(raw) }.find(&:correct?) # Array() guards a plucked NULL
    [guess&.elapsed_ms].compact
  end

  def self.median(values)
    return nil if values.empty?

    sorted = values.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
  end

  attr_reader :starts, :abandons, :median_first_group_ms

  def initialize(starts:, abandons:, median_first_group_ms:)
    @starts = starts
    @abandons = abandons
    @median_first_group_ms = median_first_group_ms
  end

  def abandon_rate
    return 0.0 if starts.zero?

    abandons.fdiv(starts)
  end

  def any?
    starts.positive? || median_first_group_ms.present?
  end
end
