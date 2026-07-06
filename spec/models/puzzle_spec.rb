require "rails_helper"

RSpec.describe Puzzle, type: :model do
  it "has a valid draft factory with just a title" do
    expect(build(:puzzle)).to be_valid
  end

  it "lets a draft save without a title" do
    # The form is answers-first with the title at the bottom, so a half-typed
    # draft auto-saves before a title exists.
    expect(build(:puzzle, title: nil, status: :unlisted)).to be_valid
  end

  it "requires a title to publish" do
    puzzle = build(:published_puzzle, title: nil)
    expect(puzzle).not_to be_valid
    expect(puzzle.errors[:title]).to be_present
  end

  it "defaults to unlisted status" do
    expect(Puzzle.new.status).to eq("unlisted")
  end

  describe "discovery metadata (specialized + description)" do
    it "defaults to Classic (not specialized)" do
      expect(Puzzle.new.specialized).to be(false)
    end

    it "allows a description up to 200 characters" do
      expect(build(:puzzle, description: "a" * 200)).to be_valid
    end

    it "rejects a description over 200 characters" do
      puzzle = build(:puzzle, description: "a" * 201)
      expect(puzzle).not_to be_valid
      expect(puzzle.errors[:description]).to be_present
    end

    it "is fine with a blank description (optional)" do
      expect(build(:puzzle, description: nil)).to be_valid
      expect(build(:puzzle, description: "")).to be_valid
    end
  end

  describe "visibility (ADR-0008)" do
    # Two axes: visibility (status enum) × completeness (derived). The three
    # author-facing states fall out of the combination.
    it "is incomplete when unlisted and not fully filled out" do
      puzzle = build(:puzzle)
      expect(puzzle).to be_unlisted
      expect(puzzle).not_to be_complete
    end

    it "is unlisted-but-ready when complete and not yet published" do
      puzzle = build(:puzzle, :complete)
      expect(puzzle).to be_unlisted
      expect(puzzle).to be_complete
    end

    it "is published once the author publishes" do
      expect(build(:published_puzzle)).to be_published
    end
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
      puzzle = build(:puzzle, status: :unlisted)
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

    # Sixteen answers means sixteen *different* answers — the game keys tiles by
    # word text, so a repeat would be unplayable (and it's just a broken puzzle).
    describe "duplicate answers" do
      it "rejects a published puzzle that repeats a word across groups" do
        puzzle = build(:published_puzzle)
        puzzle.groups.last.words = puzzle.groups.first.words.first(1) + %w[x y z]
        expect(puzzle).not_to be_valid
        expect(puzzle.errors[:groups].join).to match(/same answer/i)
      end

      it "rejects a repeat within one group" do
        puzzle = build(:published_puzzle)
        puzzle.groups.first.words = %w[twin twin odd end]
        expect(puzzle).not_to be_valid
      end

      it "catches case-and-whitespace disguises" do
        puzzle = build(:published_puzzle)
        puzzle.groups.last.words = ["  #{puzzle.groups.first.words.first.upcase} ", "x", "y", "z"]
        expect(puzzle).not_to be_valid
      end

      it "leaves drafts alone — dupes are fine while still typing" do
        puzzle = build(:puzzle, status: :unlisted)
        puzzle.groups << build(:group, puzzle: puzzle, color: :blue, words: %w[twin twin])
        expect(puzzle).to be_valid
      end
    end
  end

  describe "#complete?" do
    it "is true for a fully filled-out puzzle" do
      expect(build(:published_puzzle)).to be_complete
    end

    it "is false without a title" do
      expect(build(:published_puzzle, title: nil)).not_to be_complete
    end

    it "is false when a group is short on words" do
      puzzle = build(:published_puzzle)
      puzzle.groups.first.words = %w[only three words]
      expect(puzzle).not_to be_complete
    end

    it "is false for an empty draft" do
      expect(build(:puzzle, status: :unlisted)).not_to be_complete
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

  describe ".featured" do
    it "returns only the puzzles flagged for the homepage" do
      starred = create(:puzzle, featured: true)
      create(:puzzle, featured: false)

      expect(Puzzle.featured).to contain_exactly(starred)
    end

    it "defaults a puzzle to not featured" do
      expect(create(:puzzle).featured).to be(false)
    end
  end
end
