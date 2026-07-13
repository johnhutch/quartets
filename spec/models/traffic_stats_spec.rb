require "rails_helper"

# Traffic over a period from the first-party Visit log — humans vs bots, and the
# source breakdown (the `ai` slice is the GEO payoff).
RSpec.describe TrafficStats do
  def visit(referrer: nil, bot: false, at: Time.current)
    Visit.create!(path: "/play", referrer: referrer, bot: bot, occurred_at: at)
  end

  it "counts human views and bot hits separately" do
    visit
    visit(bot: true)
    visit(bot: true)

    stats = described_class.new(since: 1.day.ago)
    expect(stats.human_views).to eq(1)
    expect(stats.bot_hits).to eq(2)
  end

  it "breaks human views down by referrer source, with an AI slice" do
    visit(referrer: "https://chatgpt.com/")
    visit(referrer: "https://perplexity.ai/")
    visit(referrer: "https://www.google.com/")
    visit(referrer: nil) # direct

    stats = described_class.new(since: 1.day.ago)
    expect(stats.sources).to include("ai" => 2, "search" => 1, "direct" => 1)
    expect(stats.ai_referrals).to eq(2)
  end

  it "respects the window" do
    visit(at: 2.weeks.ago)
    visit

    expect(described_class.new(since: 7.days.ago).human_views).to eq(1)
  end
end
