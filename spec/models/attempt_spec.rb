require "rails_helper"

RSpec.describe Attempt, type: :model do
  it "has a valid factory" do
    expect(build(:attempt)).to be_valid
  end

  it "belongs to a puzzle" do
    expect(build(:attempt, puzzle: nil)).not_to be_valid
  end

  it "requires a player_token" do
    expect(build(:attempt, player_token: nil)).not_to be_valid
  end

  it "defaults to unsolved, zero mistakes, no guesses" do
    attempt = Attempt.new
    expect(attempt.solved).to be(false)
    expect(attempt.mistakes_count).to eq(0)
    expect(attempt.guesses).to eq([])
  end

  describe "mistakes_count bounds (NYT cap of 4)" do
    it "allows 0 through 4" do
      (0..Puzzle::MAX_MISTAKES).each do |n|
        expect(build(:attempt, mistakes_count: n)).to be_valid
      end
    end

    it "rejects more than 4" do
      expect(build(:attempt, mistakes_count: 5)).not_to be_valid
    end

    it "rejects negative counts" do
      expect(build(:attempt, mistakes_count: -1)).not_to be_valid
    end
  end

  describe "#lost?" do
    it "is true after 4 mistakes without solving" do
      expect(build(:attempt, solved: false, mistakes_count: 4)).to be_lost
    end

    it "is false if solved, even at 4 mistakes" do
      expect(build(:attempt, solved: true, mistakes_count: 4)).not_to be_lost
    end

    it "is false below the limit" do
      expect(build(:attempt, solved: false, mistakes_count: 3)).not_to be_lost
    end
  end

  describe "#finished?" do
    it "is true when solved" do
      expect(build(:attempt, solved: true, mistakes_count: 1)).to be_finished
    end

    it "is true when lost" do
      expect(build(:attempt, solved: false, mistakes_count: 4)).to be_finished
    end

    it "is false mid-game" do
      expect(build(:attempt, solved: false, mistakes_count: 2)).not_to be_finished
    end
  end

  describe "achievements (ADR-0011)" do
    # A flawless win is four correct guesses, zero mistakes; the tier is the solve
    # order (purple = hardest). Difficulty rainbow is yellow→purple, so reverse is
    # purple→blue→green→yellow.
    def correct(color)
      { "correct" => true, "words" => %w[a b c d], "colors" => Array.new(4, color) }
    end

    def flawless(order)
      build(:attempt, solved: true, mistakes_count: 0, guesses: order.map { |c| correct(c) })
    end

    describe "#earned_achievement" do
      it "is reverse_rainbow for a flawless purple→blue→green→yellow win" do
        expect(flawless(%w[purple blue green yellow]).earned_achievement).to eq(:reverse_rainbow)
      end

      it "is purple_first for a flawless win opening on purple (not full reverse)" do
        expect(flawless(%w[purple green blue yellow]).earned_achievement).to eq(:purple_first)
      end

      it "is perfect for a flawless win that doesn't open on purple" do
        expect(flawless(%w[yellow green blue purple]).earned_achievement).to eq(:perfect)
      end

      it "is nil for a win with any mistakes" do
        a = build(:attempt, solved: true, mistakes_count: 1,
                  guesses: %w[purple blue green yellow].map { |c| correct(c) })
        expect(a.earned_achievement).to be_nil
      end

      it "is nil for a loss" do
        expect(build(:attempt, solved: false, mistakes_count: 4).earned_achievement).to be_nil
      end
    end

    it "stores the tier on create" do
      expect(flawless(%w[purple blue green yellow]).tap(&:save!).reload.achievement).to eq("reverse_rainbow")
    end

    describe "#earned_tiers (cumulative, weakest→strongest)" do
      it "is empty when nothing scored" do
        expect(build(:attempt, solved: false, mistakes_count: 4).earned_tiers).to eq([])
      end

      it "is just perfect for a perfect" do
        expect(flawless(%w[yellow green blue purple]).earned_tiers).to eq(%i[perfect])
      end

      it "is all three for a reverse rainbow" do
        expect(flawless(%w[purple blue green yellow]).earned_tiers).to eq(%i[perfect purple_first reverse_rainbow])
      end
    end

    describe "#quip_bucket" do
      it "is the tier when one was earned" do
        expect(flawless(%w[purple green blue yellow]).quip_bucket).to eq(:purple_first)
      end

      it "is :mistakes for a win with mistakes" do
        expect(build(:attempt, solved: true, mistakes_count: 2).quip_bucket).to eq(:mistakes)
      end

      it "is :loss for a loss" do
        expect(build(:attempt, solved: false, mistakes_count: 4).quip_bucket).to eq(:loss)
      end
    end

    describe ".at_least (cumulative counts)" do
      it "counts a tier or better — reverse rainbow counts toward all three" do
        flawless(%w[yellow green blue purple]).save! # perfect
        flawless(%w[purple green blue yellow]).save! # purple_first (+ perfect)
        flawless(%w[purple blue green yellow]).save! # reverse_rainbow (+ both)

        expect(Attempt.at_least(:perfect).count).to eq(3)
        expect(Attempt.at_least(:purple_first).count).to eq(2)
        expect(Attempt.at_least(:reverse_rainbow).count).to eq(1)
      end
    end
  end
end
