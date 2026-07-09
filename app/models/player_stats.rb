# Dashboard top-block stats for one author/player (ADR-0011). Trophies + play
# stats are account-scoped (anonymous attempts are uncapped, so cookie totals
# would be farmable — they get only a created count and a sign-up nudge). Feed it
# the account's `attempts` relation (or nil when logged out) and the created count.
class PlayerStats
  TIERS = %i[perfect purple_first reverse_rainbow].freeze

  def initialize(attempts:, created:)
    @attempts = attempts
    @created = created
  end

  attr_reader :created

  def signed_in?
    !@attempts.nil?
  end

  def played
    totals[:played]
  end

  def solved
    totals[:solved]
  end

  # Fraction 0.0–1.0; the view turns it into a percentage.
  def solve_rate
    return 0.0 if played.zero?

    solved.fdiv(played)
  end

  # Cumulative trophy counts (a reverse rainbow also counts as a perfect). One
  # grouped query, rolled up in Ruby, instead of a COUNT per tier.
  def trophies
    levels = Attempt.achievements
    counts = @attempts.where.not(achievement: nil).group(:achievement).count
    TIERS.index_with do |tier|
      floor = levels.fetch(tier.to_s)
      counts.sum { |achievement, n| levels.fetch(achievement.to_s) >= floor ? n : 0 }
    end
  end

  private

  # played + solved in one round trip (was two separate COUNTs, re-run by solve_rate).
  def totals
    @totals ||= begin
      played, solved = @attempts.pick(Arel.sql("COUNT(*)"), Arel.sql("COUNT(*) FILTER (WHERE solved)"))
      { played: played.to_i, solved: solved.to_i }
    end
  end
end
