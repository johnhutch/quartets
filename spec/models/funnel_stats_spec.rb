require "rails_helper"

# The product funnel (analytics stream B), site-wide, over a period. Distinct
# players who reached each stage: opened a play page → started a game → finished;
# plus the create funnel (opened the form → published). All first-party Events +
# Attempts, no client tracking.
RSpec.describe FunnelStats do
  let(:puzzle) { create(:published_puzzle) }

  def opened(token); create(:event, event_type: :puzzle_opened, player_token: token, puzzle: puzzle); end
  def started(token); create(:event, event_type: :game_started, player_token: token, puzzle: puzzle); end
  def finished(token); create(:attempt, puzzle: puzzle, player_token: token, solved: true); end

  it "counts distinct players at each play-funnel stage" do
    opened("a"); opened("b"); opened("c"); opened("a") # a re-opened — still one
    started("a"); started("b")
    finished("a")

    stats = described_class.new(since: 1.day.ago)

    expect(stats.opened).to eq(3)   # a, b, c
    expect(stats.started).to eq(2)  # a, b
    expect(stats.finished).to eq(1) # a
  end

  it "gives the stage-to-stage conversion rates" do
    opened("a"); opened("b"); opened("c"); opened("d")
    started("a"); started("b")
    finished("a")

    stats = described_class.new(since: 1.day.ago)
    expect(stats.start_rate).to eq(0.5)    # 2 of 4 opened
    expect(stats.finish_rate).to eq(0.5)   # 1 of 2 started
  end

  it "counts the create funnel — form opens vs puzzles published" do
    create(:event, event_type: :authoring_opened, player_token: "x")
    create(:event, event_type: :authoring_opened, player_token: "y")
    create(:published_puzzle) # a publish in the window

    stats = described_class.new(since: 1.day.ago)
    expect(stats.authoring_opened).to eq(2)
    expect(stats.published).to be >= 1
  end

  it "nests the stages so conversion can't exceed 100% (started ⊆ opened)" do
    # game_started with history but no matching puzzle_opened (the post-deploy
    # skew) must NOT produce started > opened.
    started("ghost1"); started("ghost2"); started("ghost3")
    opened("real"); started("real")

    stats = described_class.new(since: 1.day.ago)
    expect(stats.opened).to eq(1)          # only "real" opened
    expect(stats.started).to eq(1)         # only "real" counts — ghosts excluded
    expect(stats.start_rate).to eq(1.0)    # never above 1.0
  end

  it "ignores events older than the window" do
    create(:event, event_type: :puzzle_opened, player_token: "old",
                   puzzle: puzzle, occurred_at: 2.weeks.ago)
    opened("new")

    expect(described_class.new(since: 7.days.ago).opened).to eq(1)
  end
end
