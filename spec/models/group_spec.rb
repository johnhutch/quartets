require "rails_helper"

RSpec.describe Group, type: :model do
  it "has a valid factory" do
    expect(build(:group)).to be_valid
  end

  it "belongs to a puzzle" do
    expect(build(:group, puzzle: nil)).not_to be_valid
  end

  it "requires a color" do
    expect(build(:group, color: nil)).not_to be_valid
  end

  describe "color uniqueness" do
    it "rejects a second group of the same color in one puzzle" do
      puzzle = create(:puzzle)
      create(:group, puzzle: puzzle, color: :blue)
      dupe = build(:group, puzzle: puzzle, color: :blue)
      expect(dupe).not_to be_valid
    end

    it "allows the same color across different puzzles" do
      create(:group, puzzle: create(:puzzle), color: :blue)
      other = build(:group, puzzle: create(:puzzle), color: :blue)
      expect(other).to be_valid
    end
  end

  describe "draft leniency" do
    it "allows blank description and words while the puzzle is a draft" do
      draft = create(:puzzle, status: :unlisted)
      group = build(:group, puzzle: draft, description: nil, words: [])
      expect(group).to be_valid
    end
  end

  describe "published strictness" do
    let(:published) { create(:published_puzzle) }

    it "requires a description once the puzzle is published" do
      group = published.groups.first
      group.description = nil
      expect(group).not_to be_valid
      expect(group.errors[:description]).to be_present
    end

    it "requires exactly four words once published" do
      group = published.groups.first
      group.words = %w[only three words]
      expect(group).not_to be_valid
      expect(group.errors[:words]).to be_present
    end

    it "rejects more than four words" do
      group = published.groups.first
      group.words = %w[one two three four five]
      expect(group).not_to be_valid
    end
  end

  describe "#filled_words" do
    it "strips whitespace and drops blanks" do
      group = build(:group, words: ["  sky ", "", "ocean", nil, "jeans", "denim"])
      expect(group.filled_words).to eq(%w[sky ocean jeans denim])
    end
  end
end
