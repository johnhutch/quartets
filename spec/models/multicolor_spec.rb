require "rails_helper"

# The brand's multicolor headers: a header is one continuous ribbon of letters
# whose color switches every 3–6 letters and flows across spaces (so breaks land
# mid-word, not on word boundaries). Non-deterministic by default — it re-rolls
# both the break positions and the colors on every call, so a header bands a new
# way on every page load. An optional seed: pins it for the rare caller that must
# stay stable (e.g. a header inside a cached fragment). Used for the wordmark +
# big display headings.
RSpec.describe Multicolor do
  def segs(text, **opts) = described_class.new(text, **opts).segments

  it "is lossless — the segments reassemble the original text exactly" do
    text = "QUARTETS"
    expect(segs(text).map(&:first).join).to eq(text)
  end

  it "re-rolls — the same text bands differently across calls" do
    bandings = Array.new(12) { segs("FOUR GROUPS OF FOUR WORDS") }.uniq
    expect(bandings.length).to be > 1
  end

  it "is repeatable when pinned with a seed:" do
    expect(segs("QUARTETS", seed: 7)).to eq(segs("QUARTETS", seed: 7))
  end

  it "only uses the four category colors" do
    colors = segs("FOUR GROUPS OF FOUR WORDS EACH").map(&:last).uniq
    expect(colors - %w[blue green yellow purple]).to be_empty
  end

  it "never repeats a color across a switch" do
    colors = segs("A REALLY QUITE LONG HEADING TO FORCE SWITCHES").map(&:last)
    colors.each_cons(2) { |a, b| expect(a).not_to eq(b) }
  end

  it "switches every 3–6 letters (completed runs), counting letters not spaces" do
    segments = segs("A REALLY QUITE LONG HEADING TO FORCE MANY SWITCHES HERE")
    letter_counts = segments.map { |str, _| str.count("a-zA-Z") }
    # every run but the last is a completed 3–6 letter run
    letter_counts[0..-2].each { |n| expect(n).to be_between(3, 6) }
    expect(letter_counts.last).to be <= 6
  end

  it "lets a run flow across a space (a segment can contain a space)" do
    # A space rides inside whichever run is active when it's read, so a
    # multi-word header always has at least one segment carrying a space.
    spanning = segs("ONE TWO SIX TEN").any? { |str, _| str.include?(" ") }
    expect(spanning).to be(true)
  end

  it "stays mono for a short word" do
    expect(segs("HI").length).to eq(1)
  end
end
