# Site-wide traffic over a period (analytics stream A), from the first-party Visit
# log. Human page views vs bot hits, and a source breakdown whose `ai` slice is
# the GEO/AEO payoff — how much traffic answer engines are sending. All grouped in
# SQL off the denormalized `source` column.
class TrafficStats
  def initialize(since: 7.days.ago)
    @since = since
  end

  def human_views
    humans.count
  end

  def bot_hits
    scope.bots.count
  end

  # { direct:, ai:, search:, social:, other: } — human views by referrer source.
  def sources
    counts = humans.group(:source).count
    %w[direct ai search social other].index_with { |s| counts.fetch(s, 0) }
  end

  def ai_referrals
    sources.fetch("ai", 0)
  end

  private

  def scope
    Visit.where(occurred_at: @since..)
  end

  def humans
    scope.humans
  end
end
