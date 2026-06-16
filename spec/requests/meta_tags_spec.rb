require "rails_helper"

# SEO meta descriptions. One computed string feeds <meta name="description">,
# og:description, and twitter:description so the SERP snippet and social unfurl
# agree. Puzzle pages prefer the author's shareable blurb and fall back to a
# generated, spoiler-free line; everything else gets the site default.
RSpec.describe "Meta descriptions", type: :request do
  def meta(body, selector)
    Nokogiri::HTML(body).at(selector)&.[]("content")
  end

  describe "the homepage and generic pages" do
    it "carries the site default description" do
      create(:published_puzzle) # featured pick has something to show
      get root_path

      expect(meta(response.body, "meta[name='description']"))
        .to eq("Create and play Connections-style puzzles.")
    end
  end

  describe "a puzzle page" do
    it "uses the author's description when present, across all three tags" do
      puzzle = create(:published_puzzle,
                      description: "Household objects hiding in plain sight.")

      get play_path(puzzle.share_token)

      blurb = "Household objects hiding in plain sight."
      expect(meta(response.body, "meta[name='description']")).to eq(blurb)
      expect(meta(response.body, "meta[property='og:description']")).to eq(blurb)
      expect(meta(response.body, "meta[name='twitter:description']")).to eq(blurb)
    end

    it "falls back to a generated line naming the author when there's no description" do
      puzzle = create(:published_puzzle, description: nil, author_name: "Hutch")

      get play_path(puzzle.share_token)

      expect(meta(response.body, "meta[name='description']"))
        .to eq("A Connections-style puzzle (but better) by Hutch. Play it free on Quartets.")
    end

    it "drops the author clause when the puzzle is anonymous" do
      puzzle = create(:published_puzzle, description: nil, author_name: nil)

      get play_path(puzzle.share_token)

      expect(meta(response.body, "meta[name='description']"))
        .to eq("A Connections-style puzzle (but better). Play it free on Quartets.")
    end
  end
end
