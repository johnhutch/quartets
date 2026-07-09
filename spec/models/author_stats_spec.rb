require "rails_helper"

# The dashboard's author-side aggregate: how your puzzles are doing out in the
# world — plays + crowd solve rate across all of them, and the ratings received
# (reusing RatingSummary for the thumb/difficulty shaping).
RSpec.describe AuthorStats do
  it "aggregates plays, solves, and ratings across the author's puzzles" do
    user = create(:user)
    first  = create(:published_puzzle, user: user)
    second = create(:published_puzzle, user: user)
    create(:attempt, puzzle: first,  solved: true,  quality: :yeah,      difficulty: :pretty_easy)
    create(:attempt, puzzle: second, solved: false, quality: :hell_yeah, difficulty: :pretty_hard)
    create(:attempt) # someone else's puzzle — not ours, not counted

    stats = described_class.for(Puzzle.where(user: user))

    expect(stats.plays).to eq(2)
    expect(stats.solves).to eq(1)
    expect(stats.crowd_solve_rate).to eq(0.5)
    expect(stats.rating.thumbs).to eq(3)            # yeah(1) + hell_yeah(2)
    expect(stats.rating.difficulty_label).to eq("Not bad") # avg(0, 2) rounds to 1
    expect(stats).to be_any
  end

  it "stays quiet (not any?) while nobody has played" do
    user = create(:user)
    create(:puzzle, user: user)

    expect(described_class.for(Puzzle.where(user: user))).not_to be_any
  end
end
