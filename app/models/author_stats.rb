# The dashboard's author-side aggregate (companion to PlayerStats' player side):
# every attempt recorded against the author's puzzles, collapsed to reach
# (plays), crowd solve rate, and the ratings received. One query; the rating
# half reuses RatingSummary so the labels/weighting stay in one place.
class AuthorStats
  def self.for(puzzles)
    plays, solves, thumbs, difficulty_avg =
      Attempt.where(puzzle_id: puzzles.except(:order, :includes).select(:id))
             .pick(
               Arel.sql("COUNT(*)"),
               Arel.sql("COUNT(*) FILTER (WHERE solved)"),
               Arel.sql("SUM(quality)"),
               Arel.sql("AVG(difficulty)")
             )

    new(plays: plays.to_i, solves: solves.to_i,
        rating: RatingSummary.new(thumbs: thumbs, difficulty_avg: difficulty_avg))
  end

  attr_reader :plays, :solves, :rating

  def initialize(plays:, solves:, rating:)
    @plays = plays
    @solves = solves
    @rating = rating
  end

  def crowd_solve_rate
    return 0.0 if plays.zero?

    solves.fdiv(plays)
  end

  def any?
    plays.positive?
  end
end
