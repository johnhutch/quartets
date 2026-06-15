require "rails_helper"

# The importer parses a genuinely messy archive: heading levels swing ##–####
# (even within one puzzle), color case varies, some groups use markdown bullets
# and others plain lines, words are comma-separated with multi-word entries, and
# a few blocks are junk. The fixture mirrors the real file's formats.
RSpec.describe ObsidianArchive do
  let(:markdown) { Rails.root.join("spec/fixtures/files/connections_archive.md").read }

  describe ".parse" do
    subject(:puzzles) { described_class.parse(markdown) }

    it "finds every titled block, including the junk ones" do
      titles = puzzles.map { |p| p[:title] }
      expect(titles).to eq([
        "Gillespie",
        "Heroes and Villains",
        "my favorite hockey boys",
        "WORLD CHAMPIONS OF BASEBALL",
        "balls"
      ])
    end

    it "parses bullet-style groups, stripping bullets and trailing italics" do
      gillespie = puzzles.find { |p| p[:title] == "Gillespie" }
      blue = gillespie[:groups].find { |g| g[:color] == "blue" }

      expect(blue[:description]).to eq("ear ___")
      expect(blue[:words]).to eq(%w[Drum Ring Lobe Muff])
    end

    it "keeps multi-word answers intact (splits on commas, not spaces)" do
      gillespie = puzzles.find { |p| p[:title] == "Gillespie" }
      purple = gillespie[:groups].find { |g| g[:color] == "purple" }

      expect(purple[:words]).to eq(["Sax", "lox", "Yurt", "Manhattan Borough"])
    end

    it "normalizes color case and tolerates mixed heading levels" do
      hockey = puzzles.find { |p| p[:title] == "my favorite hockey boys" }
      expect(hockey[:groups].map { |g| g[:color] }).to contain_exactly("green", "yellow", "blue", "purple")
    end

    it "yields no groups for a block without color headers" do
      champs = puzzles.find { |p| p[:title] == "WORLD CHAMPIONS OF BASEBALL" }
      expect(champs[:groups]).to be_empty
    end

    it "leaves an incomplete group's words empty rather than guessing" do
      balls = puzzles.find { |p| p[:title] == "balls" }
      purple = balls[:groups].find { |g| g[:color] == "purple" }
      expect(purple[:words]).to be_empty
    end
  end

  describe ".import" do
    let(:user) { create(:user) }

    it "publishes complete puzzles, leaves partial ones unlisted, and skips junk" do
      summary = described_class.import(markdown, user: user)

      expect(summary[:published]).to contain_exactly(
        "Gillespie", "Heroes and Villains", "my favorite hockey boys"
      )
      expect(summary[:unlisted]).to contain_exactly("balls")
      expect(summary[:skipped]).to contain_exactly("WORLD CHAMPIONS OF BASEBALL")
    end

    it "persists a complete puzzle, published, with its four groups" do
      described_class.import(markdown, user: user)

      gillespie = user.puzzles.find_by(title: "Gillespie")
      expect(gillespie).to be_published
      expect(gillespie.groups.count).to eq(4)
      expect(gillespie.groups.find_by(color: :blue).words).to eq(%w[Drum Ring Lobe Muff])
    end

    it "salvages a partial puzzle as a draft" do
      described_class.import(markdown, user: user)
      expect(user.puzzles.find_by(title: "balls")).to be_unlisted
    end

    it "is idempotent — re-running imports nothing new" do
      described_class.import(markdown, user: user)
      expect { described_class.import(markdown, user: user) }.not_to change(Puzzle, :count)
    end
  end
end
