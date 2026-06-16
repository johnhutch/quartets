require "rails_helper"

# The payload shown after a finished play: cube, share block, earned tier, and the
# trophies-block locals. One owner so attempts#create (JSON) and the revisit view
# (play/_result) stop each computing it. Pure value object; the URL is handed in.
RSpec.describe PlayResult do
  let(:url) { "https://quartets.example/p/abc" }

  def flawless_attempt(user: nil, order: %w[purple blue green yellow])
    create(:attempt, user: user, solved: true, mistakes_count: 0,
           guesses: order.map { |c| { "words" => %w[a b c d], "colors" => [c] * 4 } })
  end

  it "builds the cube from the attempt's guess log" do
    attempt = flawless_attempt
    expect(described_class.new(attempt, url: url, viewer: nil).cube)
      .to eq(EmojiCube.new(attempt.guess_log).to_s)
  end

  it "builds the share block from the puzzle title, the cube, and the url" do
    attempt = flawless_attempt
    result = described_class.new(attempt, url: url, viewer: nil)
    expect(result.share).to include("Quartets — #{attempt.puzzle.title}")
    expect(result.share).to include(result.cube)
    expect(result.share).to include(url)
  end

  it "exposes the earned achievement tier" do
    result = described_class.new(flawless_attempt, url: url, viewer: nil)
    expect(result.achievement).to eq("reverse_rainbow")
  end

  describe "#awards_locals" do
    it "gives a signed-in winner a running total of their top trophy" do
      user = create(:user)
      flawless_attempt(user: user, order: %w[yellow green blue purple]) # perfect (different puzzle)
      attempt = flawless_attempt(user: user)                            # reverse rainbow

      locals = described_class.new(attempt, url: url, viewer: user).awards_locals

      expect(locals[:signed_in]).to be(true)
      expect(locals[:total]).to eq(1) # one reverse_rainbow to their name
      expect(locals[:attempt]).to eq(attempt)
    end

    it "gives an anonymous player no total — the sign-up nudge path" do
      locals = described_class.new(flawless_attempt, url: url, viewer: nil).awards_locals
      expect(locals[:signed_in]).to be(false)
      expect(locals[:total]).to be_nil
    end

    it "has no total when no trophy was earned (a flawed win)" do
      user = create(:user)
      attempt = create(:attempt, user: user, solved: true, mistakes_count: 2)
      locals = described_class.new(attempt, url: url, viewer: user).awards_locals
      expect(locals[:total]).to be_nil
    end
  end
end
