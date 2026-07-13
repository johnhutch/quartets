# The analytics tab (superuser-only): first-party traffic (stream A) + product
# funnels (stream B) over a window. Everything's derived on read from the Visit /
# Event / Attempt logs — no third party, no client tracking.
class Admin::AnalyticsController < Admin::BaseController
  before_action :require_superuser # analytics is owner-grade, not for moderators

  PERIODS = { "7" => 7, "30" => 30, "90" => 90 }.freeze

  def index
    @days = PERIODS.fetch(params[:days], 30)
    since = @days.days.ago
    @traffic = TrafficStats.new(since: since)
    @funnel = FunnelStats.new(since: since)
  end
end
