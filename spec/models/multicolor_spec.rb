require "rails_helper"

# The brand's multicolor headers: a header is one continuous ribbon of letters
# whose color switches every 4–7 letters and flows across spaces (so breaks land
# mid-word, not on word boundaries). Deterministic — seeded on the text — so it's
# stable, codifiable, and testable. Used for the wordmark + big display headings.
RSpec.describe Multicolor do
  def segs(text) = described_class.new(text).segments

  it "is lossless — the segments reassemble the original text exactly" do
    text = "QUARTETS"
    expect(segs(text).map(&:first).join).to eq(text)
  end

  it "is deterministic — same text bands the same way every time" do
    expect(segs("QUARTETS")).to eq(segs("QUARTETS"))
  end

  it "varies between different texts" do
    expect(segs("QUARTETS")).not_to eq(segs("STYLE GUIDE"))
  end

  it "only uses the four category colors" do
    colors = segs("FOUR GROUPS OF FOUR WORDS EACH").map(&:last).uniq
    expect(colors - %w[blue green yellow purple]).to be_empty
  end

  it "never repeats a color across a switch" do
    colors = segs("A REALLY QUITE LONG HEADING TO FORCE SWITCHES").map(&:last)
    colors.each_cons(2) { |a, b| expect(a).not_to eq(b) }
  end

  it "switches every 4–7 letters (completed runs), counting letters not spaces" do
    segments = segs("A REALLY QUITE LONG HEADING TO FORCE MANY SWITCHES HERE")
    letter_counts = segments.map { |str, _| str.count("a-zA-Z") }
    # every run but the last is a completed 4–7 letter run
    letter_counts[0..-2].each { |n| expect(n).to be_between(4, 7) }
    expect(letter_counts.last).to be <= 7
  end

  it "lets a run flow across a space (a segment can contain a space)" do
    # With runs of 4–7 letters, at least one break won't align to a word edge.
    spanning = segs("ONE TWO SIX TEN").any? { |str, _| str.include?(" ") }
    expect(spanning).to be(true)
  end

  it "stays mono for a short word" do
    expect(segs("HI").length).to eq(1)
  end
end
