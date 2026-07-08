require "rails_helper"

# Per-puzzle analytics, derived purely from the recorded attempts (and their
# guesses jsonb) — no rollup table. Pure logic, so it gets tight coverage.
RSpec.describe PuzzleStats do
  def attempt(solved:, mistakes:, guesses: [])
    build(:attempt, solved: solved, mistakes_count: mistakes, guesses: guesses)
  end

  describe "headline numbers" do
    it "counts total attempts" do
      stats = described_class.new([attempt(solved: true, mistakes: 0), attempt(solved: false, mistakes: 4)])
      expect(stats.total_attempts).to eq(2)
    end

    it "computes the solve rate as a fraction" do
      attempts = [
        attempt(solved: true,  mistakes: 1),
        attempt(solved: true,  mistakes: 2),
        attempt(solved: false, mistakes: 4),
        attempt(solved: false, mistakes: 4)
      ]
      expect(described_class.new(attempts).solve_rate).to eq(0.5)
    end

    it "is a zero solve rate (not a divide-by-zero) with no attempts" do
      stats = described_class.new([])
      expect(stats.total_attempts).to eq(0)
      expect(stats.solve_rate).to eq(0.0)
    end
  end

  describe "#mistakes_distribution" do
    it "buckets attempts by mistake count, 0 through the cap" do
      attempts = [
        attempt(solved: true,  mistakes: 0),
        attempt(solved: true,  mistakes: 2),
        attempt(solved: true,  mistakes: 2),
        attempt(solved: false, mistakes: 4)
      ]
      expect(described_class.new(attempts).mistakes_distribution).to eq(
        0 => 1, 1 => 0, 2 => 2, 3 => 0, 4 => 1
      )
    end
  end

  describe "#common_wrong_guesses" do
    it "tallies wrong guesses (mixed colors) regardless of pick order" do
      attempts = [
        attempt(solved: false, mistakes: 4, guesses: [
          { "words" => %w[cat dog owl one], "colors" => %w[blue blue blue green] },
          { "words" => %w[cat dog owl fox], "colors" => %w[blue blue blue blue] } # correct — ignored
        ]),
        attempt(solved: true, mistakes: 1, guesses: [
          { "words" => %w[one owl dog cat], "colors" => %w[green blue blue blue] } # same set, different order
        ])
      ]

      common = described_class.new(attempts).common_wrong_guesses

      # Word–color pairs, canonically sorted by word, so the view can render
      # each word as a chip in its true category color.
      expect(common.first[:tiles]).to eq([
        { word: "cat", color: "blue" },
        { word: "dog", color: "blue" },
        { word: "one", color: "green" },
        { word: "owl", color: "blue" }
      ])
      expect(common.first[:count]).to eq(2)
    end

    it "skips correct guesses and caps the list" do
      guesses = [{ "words" => %w[a b c d], "colors" => %w[blue blue blue blue] }]
      stats = described_class.new([attempt(solved: true, mistakes: 0, guesses: guesses)])
      expect(stats.common_wrong_guesses).to be_empty
    end
  end
end
