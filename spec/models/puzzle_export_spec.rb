require "rails_helper"

# The portable JSON shape for a puzzle. Schema is a contract, so it's pinned
# here — change it deliberately, not by accident.
RSpec.describe PuzzleExport do
  it "serializes title, author, and ordered groups" do
    puzzle = create(:published_puzzle, title: "Export Me", author_name: "Hutch")

    hash = described_class.new(puzzle).to_h

    expect(hash["title"]).to eq("Export Me")
    expect(hash["author"]).to eq("Hutch")
    expect(hash["groups"].map { |g| g["color"] }).to eq(%w[blue green yellow purple])

    first = hash["groups"].first
    expect(first.keys).to contain_exactly("color", "description", "words")
    expect(first["words"]).to eq(%w[alpha bravo charlie delta])
    expect(first["description"]).to be_present
  end

  it "renders compact JSON" do
    puzzle = create(:published_puzzle)
    expect { JSON.parse(described_class.new(puzzle).to_json) }.not_to raise_error
  end

  describe "#filename" do
    it "slugs the title" do
      puzzle = build(:puzzle, title: "My Cool Puzzle!")
      expect(described_class.new(puzzle).filename).to eq("my-cool-puzzle.json")
    end

    it "falls back when there's no title yet" do
      puzzle = build(:puzzle, title: nil)
      expect(described_class.new(puzzle).filename).to eq("puzzle.json")
    end
  end
end
