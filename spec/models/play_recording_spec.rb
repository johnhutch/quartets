require "rails_helper"

# Server-side reconstruction of a finished play: the client is trusted only with
# the words it grouped; colors, correctness, mistakes, and solved are derived from
# the puzzle so a forged POST can't mint trophies or poison stats.
RSpec.describe PlayRecording do
  let(:puzzle) { create(:published_puzzle) } # blue cat/dog/owl/fox, green one/two/three/four, etc.

  def guess(*words, t: nil)
    h = { "words" => words }
    h["t"] = t if t
    h
  end

  it "derives colors from the puzzle, ignoring anything the client claims" do
    rec = described_class.new(puzzle, [guess("cat", "dog", "owl", "one")])
    expect(rec).to be_valid
    expect(rec.guesses.first["colors"]).to eq(%w[blue blue blue green])
  end

  it "derives solved from four correctly-colored groups, not a client flag" do
    all_correct = [
      guess("cat", "dog", "owl", "fox"),
      guess("one", "two", "three", "four"),
      guess("mercury", "venus", "mars", "earth"),
      guess("piano", "drums", "bass", "flute")
    ]
    expect(described_class.new(puzzle, all_correct)).to be_solved
    expect(described_class.new(puzzle, all_correct.first(3))).not_to be_solved
  end

  it "counts mistakes from wrong guesses, capped at the game limit" do
    wrongs = Array.new(6) { guess("cat", "dog", "owl", "one") } # each spans two colors
    expect(described_class.new(puzzle, wrongs).mistakes_count).to eq(Puzzle::MAX_MISTAKES)
  end

  it "does not call an empty log solved (the forged-perfect hole)" do
    rec = described_class.new(puzzle, [])
    expect(rec).to be_valid
    expect(rec).not_to be_solved
    expect(rec.mistakes_count).to eq(0)
  end

  it "rejects a guess containing words not in the puzzle" do
    rec = described_class.new(puzzle, [guess("cat", "dog", "owl", "ZZZ")])
    expect(rec).not_to be_valid
  end

  it "rejects a guess that isn't four words" do
    expect(described_class.new(puzzle, [guess("cat", "dog", "owl")])).not_to be_valid
  end

  it "rejects an implausibly long log" do
    long = Array.new(described_class::MAX_GUESSES + 1) { guess("cat", "dog", "owl", "fox") }
    expect(described_class.new(puzzle, long)).not_to be_valid
  end

  it "keeps per-guess timing and total duration" do
    rec = described_class.new(puzzle, [guess("cat", "dog", "owl", "fox", t: 4200)], duration_ms: 18_500)
    expect(rec.guesses.first["t"]).to eq(4200)
    expect(rec.attempt_attributes[:duration_ms]).to eq(18_500)
  end
end
