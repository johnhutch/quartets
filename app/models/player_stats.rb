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
    @attempts.count
  end

  def solved
    @attempts.where(solved: true).count
  end

  # Fraction 0.0–1.0; the view turns it into a percentage.
  def solve_rate
    return 0.0 if played.zero?

    solved.fdiv(played)
  end

  # Cumulative trophy counts (a reverse rainbow also counts as a perfect).
  def trophies
    TIERS.index_with { |tier| @attempts.at_least(tier).count }
  end
end
