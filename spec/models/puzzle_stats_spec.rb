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

  describe "solve timing" do
    def timed(duration_ms, solved: true)
      build(:attempt, solved: solved, mistakes_count: 0, duration_ms: duration_ms)
    end

    it "reports median and fastest from solved, timed attempts only" do
      stats = described_class.new([
        timed(240_000), timed(60_000), timed(120_000),
        timed(5_000, solved: false),  # a loss doesn't count as a solve time
        timed(nil)                    # pre-timing attempt — no data
      ])

      expect(stats.median_solve_ms).to eq(120_000)
      expect(stats.fastest_solve_ms).to eq(60_000)
    end

    it "averages the middle pair on an even count" do
      stats = described_class.new([timed(60_000), timed(120_000)])
      expect(stats.median_solve_ms).to eq(90_000)
    end

    it "is nil with no timed solves" do
      stats = described_class.new([timed(nil), timed(90_000, solved: false)])
      expect(stats.median_solve_ms).to be_nil
      expect(stats.fastest_solve_ms).to be_nil
    end
  end

  describe "#flawless_count" do
    it "counts clean solves only" do
      stats = described_class.new([
        attempt(solved: true,  mistakes: 0),
        attempt(solved: true,  mistakes: 2),
        attempt(solved: false, mistakes: 0) # abandoned clean board isn't flawless
      ])
      expect(stats.flawless_count).to eq(1)
    end
  end

  describe "#trophy_counts" do
    it "counts cumulatively — a reverse rainbow is also a purple-first and a perfect" do
      stats = described_class.new([
        build(:attempt, solved: true, achievement: :perfect),
        build(:attempt, solved: true, achievement: :reverse_rainbow),
        build(:attempt, solved: true, achievement: nil) # flawed win, no trophy
      ])

      expect(stats.trophy_counts).to eq(perfect: 2, purple_first: 1, reverse_rainbow: 1)
    end
  end

  describe "#common_solve_orders" do
    def solved_in(*colors)
      guesses = colors.map { |c| { "words" => %w[w x y z], "colors" => [c, c, c, c] } }
      build(:attempt, solved: true, mistakes_count: 0, guesses: guesses)
    end

    it "tallies complete solve orders of solved attempts, most frequent first" do
      stats = described_class.new([
        solved_in("yellow", "green", "blue", "purple"),
        solved_in("yellow", "green", "blue", "purple"),
        solved_in("purple", "blue", "green", "yellow"),
        build(:attempt, solved: false, guesses: [
          { "words" => %w[w x y z], "colors" => %w[blue blue blue blue] }
        ]) # a loss's partial order doesn't count
      ])

      orders = stats.common_solve_orders
      expect(orders.first).to eq(colors: %w[yellow green blue purple], count: 2)
      expect(orders.second).to eq(colors: %w[purple blue green yellow], count: 1)
    end
  end
end
