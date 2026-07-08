require "rails_helper"

# Read-side aggregate of the post-play votes (ADR: punch list 2026-07-08).
# Quality's enum integers double as thumb weights — yeah 1, hell yeah 2 — so the
# weighted thumb count is just SUM(quality). Difficulty is the average of the
# 0–3 scale rounded back to its label.
RSpec.describe RatingSummary do
  let(:puzzle) { create(:published_puzzle) }

  describe ".for" do
    it "sums quality votes weighted by intensity" do
      create(:attempt, puzzle: puzzle, quality: :yeah)      # 1
      create(:attempt, puzzle: puzzle, quality: :yeah)      # 1
      create(:attempt, puzzle: puzzle, quality: :hell_yeah) # 2

      summary = described_class.for([puzzle])[puzzle.id]

      expect(summary.thumbs).to eq(4)
    end

    it "labels the average difficulty, rounded" do
      create(:attempt, puzzle: puzzle, difficulty: :pretty_easy) # 0
      create(:attempt, puzzle: puzzle, difficulty: :cursed)      # 3
      # avg 1.5 rounds to 2 → "Pretty hard"

      summary = described_class.for([puzzle])[puzzle.id]

      expect(summary.difficulty_label).to eq("Pretty hard")
    end

    it "keeps the sweary top label intact" do
      create(:attempt, puzzle: puzzle, difficulty: :cursed)

      summary = described_class.for([puzzle])[puzzle.id]

      expect(summary.difficulty_label).to eq("@!#?@!")
    end

    it "reports the difficulty as a 1–4 meter level (enum 0–3 → +1)" do
      create(:attempt, puzzle: puzzle, difficulty: :pretty_easy) # 0 → 1
      create(:attempt, puzzle: puzzle, difficulty: :cursed)      # 3 → avg 1.5 → round 2 → 3

      summary = described_class.for([puzzle])[puzzle.id]

      expect(summary.difficulty_level).to eq(3)
    end

    it "handles one vote kind without the other" do
      create(:attempt, puzzle: puzzle, quality: :hell_yeah, difficulty: nil)

      summary = described_class.for([puzzle])[puzzle.id]

      expect(summary.thumbs).to eq(2)
      expect(summary.difficulty_label).to be_nil
    end

    it "omits puzzles with attempts but no votes at all" do
      create(:attempt, puzzle: puzzle, quality: nil, difficulty: nil)

      expect(described_class.for([puzzle])).not_to have_key(puzzle.id)
    end

    it "omits puzzles with no attempts" do
      expect(described_class.for([puzzle])).to eq({})
    end

    it "aggregates several puzzles in one pass" do
      other = create(:published_puzzle)
      create(:attempt, puzzle: puzzle, quality: :yeah)
      create(:attempt, puzzle: other, difficulty: :not_bad)

      summaries = described_class.for([puzzle, other])

      expect(summaries[puzzle.id].thumbs).to eq(1)
      expect(summaries[other.id].difficulty_label).to eq("Not bad")
    end
  end

  describe ".for_puzzle" do
    it "returns the single puzzle's summary, or nil when unrated" do
      create(:attempt, puzzle: puzzle, quality: :yeah)

      expect(described_class.for_puzzle(puzzle).thumbs).to eq(1)
      expect(described_class.for_puzzle(create(:published_puzzle))).to be_nil
    end
  end
end
