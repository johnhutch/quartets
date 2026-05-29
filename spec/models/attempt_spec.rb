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
end
