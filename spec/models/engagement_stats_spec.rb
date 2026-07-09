require "rails_helper"

# Superuser-only funnel numbers, per puzzle: game_started beacons vs recorded
# attempts (abandons), and how long the first correct group takes. Built like
# RatingSummary — .for takes a page of puzzles, one entry per puzzle with data.
RSpec.describe EngagementStats do
  describe ".for" do
    it "counts starts, abandons, and the abandon rate per puzzle" do
      puzzle = create(:published_puzzle)
      quiet  = create(:published_puzzle)

      create(:event, puzzle: puzzle, player_token: "a")
      create(:event, puzzle: puzzle, player_token: "b")
      create(:event, puzzle: puzzle, player_token: "c")
      create(:attempt, puzzle: puzzle, player_token: "a")

      stats = described_class.for([puzzle, quiet])

      expect(stats[puzzle.id].starts).to eq(3)
      expect(stats[puzzle.id].abandons).to eq(2)
      expect(stats[puzzle.id].abandon_rate).to be_within(0.001).of(2.0 / 3)
      expect(stats[quiet.id]).to be_nil # no signal, no entry
    end

    it "dedupes repeat starts from the same player" do
      puzzle = create(:published_puzzle)
      create(:event, puzzle: puzzle, player_token: "a")
      create(:event, puzzle: puzzle, player_token: "a") # revisited, tapped again

      expect(described_class.for([puzzle])[puzzle.id].starts).to eq(1)
    end

    it "reports the median time-to-first-group from the guess logs" do
      puzzle = create(:published_puzzle)
      solve = ->(t) { [{ "words" => %w[w x y z], "colors" => %w[blue blue blue blue], "t" => t }] }
      create(:attempt, puzzle: puzzle, player_token: "a", guesses: solve.call(30_000))
      create(:attempt, puzzle: puzzle, player_token: "b", guesses: solve.call(90_000))
      # wrong-only attempt (never cracked a group) and an untimed log: no signal
      create(:attempt, puzzle: puzzle, player_token: "c", guesses: [
        { "words" => %w[w x y z], "colors" => %w[blue blue blue green] }
      ])

      expect(described_class.for([puzzle])[puzzle.id].median_first_group_ms).to eq(60_000)
    end
  end
end
