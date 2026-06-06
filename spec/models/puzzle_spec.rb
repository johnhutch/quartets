require "rails_helper"

RSpec.describe Puzzle, type: :model do
  it "has a valid draft factory with just a title" do
    expect(build(:puzzle)).to be_valid
  end

  it "lets a draft save without a title" do
    # The form is answers-first with the title at the bottom, so a half-typed
    # draft auto-saves before a title exists.
    expect(build(:puzzle, title: nil, status: :draft)).to be_valid
  end

  it "requires a title to publish" do
    puzzle = build(:published_puzzle, title: nil)
    expect(puzzle).not_to be_valid
    expect(puzzle.errors[:title]).to be_present
  end

  it "defaults to draft status" do
    expect(Puzzle.new.status).to eq("draft")
  end

  it "auto-generates a share_token on create" do
    puzzle = create(:puzzle)
    expect(puzzle.share_token).to be_present
  end

  it "gives each puzzle a distinct share_token" do
    expect(create(:puzzle).share_token).not_to eq(create(:puzzle).share_token)
  end

  it "pins the NYT mistake limit at 4" do
    expect(Puzzle::MAX_MISTAKES).to eq(4)
  end

  describe "structural rules" do
    it "lets a draft save with fewer than four groups" do
      puzzle = build(:puzzle, status: :draft)
      puzzle.groups << build(:group, puzzle: puzzle, color: :blue)
      expect(puzzle).to be_valid
    end

    it "accepts a complete published puzzle" do
      expect(build(:published_puzzle)).to be_valid
    end

    it "rejects a published puzzle without exactly four groups" do
      puzzle = build(:published_puzzle)
      puzzle.groups = puzzle.groups.first(3)
      expect(puzzle).not_to be_valid
      expect(puzzle.errors[:groups]).to be_present
    end

    it "rejects a published puzzle whose colors aren't all four" do
      puzzle = build(:published_puzzle)
      puzzle.groups.last.color = :blue # now two blues, missing purple
      expect(puzzle).not_to be_valid
      expect(puzzle.errors[:groups]).to be_present
    end
  end

  describe "associations" do
    it "destroys its groups and attempts when destroyed" do
      puzzle = create(:published_puzzle)
      create(:attempt, puzzle: puzzle)
      expect { puzzle.destroy }
        .to change(Group, :count).by(-Puzzle::GROUPS_PER_PUZZLE)
        .and change(Attempt, :count).by(-1)
    end
  end
end
