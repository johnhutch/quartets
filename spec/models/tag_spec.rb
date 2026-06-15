require "rails_helper"

RSpec.describe Tag, type: :model do
  describe ".normalize" do
    it "downcases and hyphenates whitespace" do
      expect(Tag.normalize("Star Wars")).to eq("star-wars")
    end

    it "collapses runs of junk/space and trims edges" do
      expect(Tag.normalize("  90s   Music! ")).to eq("90s-music")
    end

    it "keeps meaningful internal hyphens" do
      expect(Tag.normalize("sci-fi")).to eq("sci-fi")
    end

    it "returns nil for blank/junk-only input" do
      expect(Tag.normalize("   ")).to be_nil
      expect(Tag.normalize("!!!")).to be_nil
    end
  end

  describe ".for_name" do
    it "finds or creates one canonical row regardless of input spelling" do
      a = Tag.for_name("Star Wars")
      b = Tag.for_name("  star  wars ")
      expect(a).to eq(b)
      expect(Tag.where(name: "star-wars").count).to eq(1)
    end

    it "is nil for input that normalizes to nothing" do
      expect(Tag.for_name("  ")).to be_nil
    end
  end
end

RSpec.describe "Puzzle tagging", type: :model do
  it "assigns tags from a list of raw names, normalized and deduped" do
    puzzle = create(:puzzle)
    puzzle.tag_names = ["Star Wars", "star wars", "  ", "Bluey"]

    expect(puzzle.tags.map(&:name)).to contain_exactly("star-wars", "bluey")
    expect(puzzle.tag_names).to contain_exactly("star-wars", "bluey")
  end

  it "accepts a comma/newline string too" do
    puzzle = create(:puzzle)
    puzzle.tag_names = "Marvel, star wars\nNFL"

    expect(puzzle.tags.map(&:name)).to contain_exactly("marvel", "star-wars", "nfl")
  end

  it "replaces the set on reassignment" do
    puzzle = create(:puzzle)
    puzzle.tag_names = ["Star Wars"]
    puzzle.tag_names = ["Bluey"]

    expect(puzzle.tags.map(&:name)).to contain_exactly("bluey")
  end

  it "tears down its taggings when destroyed (but leaves the shared tags)" do
    puzzle = create(:puzzle)
    puzzle.tag_names = ["Star Wars"]

    expect { puzzle.destroy }.to change(Tagging, :count).by(-1).and change(Tag, :count).by(0)
  end
end
