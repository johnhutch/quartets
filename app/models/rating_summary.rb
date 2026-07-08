# Read-side aggregate of the post-play votes stored on attempts (quality +
# difficulty, both nullable enums). Quality's enum integers double as thumb
# weights — yeah 1, hell yeah 2 — so the weighted thumb count is SUM(quality).
# Difficulty reads as the average of the 0–3 scale rounded back to its label.
#
# Built for list surfaces: .for takes the whole page of puzzles and comes back
# with one grouped query, keyed by puzzle_id. Unrated puzzles get no entry, so
# views can render-if-present and the cold-start archive stays clean.
class RatingSummary
  DIFFICULTY_LABELS = {
    "pretty_easy" => "Pretty easy",
    "not_bad"     => "Not bad",
    "pretty_hard" => "Pretty hard",
    "cursed"      => "@!#?@!"
  }.freeze

  attr_reader :thumbs

  def self.for(puzzles)
    Attempt.where(puzzle: puzzles)
           .group(:puzzle_id)
           .pluck(:puzzle_id, Arel.sql("SUM(quality)"), Arel.sql("AVG(difficulty)"))
           .each_with_object({}) do |(puzzle_id, thumbs, difficulty_avg), summaries|
      summary = new(thumbs: thumbs, difficulty_avg: difficulty_avg)
      summaries[puzzle_id] = summary if summary.any?
    end
  end

  def self.for_puzzle(puzzle)
    self.for([puzzle])[puzzle.id]
  end

  def initialize(thumbs:, difficulty_avg:)
    @thumbs = thumbs&.to_i
    @difficulty_avg = difficulty_avg
  end

  def difficulty_label
    return nil unless @difficulty_avg

    DIFFICULTY_LABELS.fetch(Attempt.difficulties.key(@difficulty_avg.round))
  end

  # 1–4 for the meter widget (the enum runs 0–3, easiest→hardest).
  def difficulty_level
    return nil unless @difficulty_avg

    @difficulty_avg.round + 1
  end

  def any?
    @thumbs.present? || @difficulty_avg.present?
  end
end
