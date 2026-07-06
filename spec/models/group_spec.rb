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

    # The authoring form's color-swap updates both groups in one nested save.
    # Validation has to judge the incoming set, not each record against the
    # stale DB, or every swap 422s.
    it "allows two sibling groups to swap colors in one nested save" do
      puzzle = create(:puzzle, :complete)
      yellow = puzzle.groups.find_by(color: "yellow")
      purple = puzzle.groups.find_by(color: "purple")

      puzzle.assign_attributes(groups_attributes: [
        { id: yellow.id, color: "purple" },
        { id: purple.id, color: "yellow" }
      ])

      expect(puzzle.save).to be(true)
      expect(yellow.reload.color).to eq("purple")
      expect(purple.reload.color).to eq("yellow")
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
