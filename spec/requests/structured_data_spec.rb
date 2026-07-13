require "rails_helper"

# Canonical tags + JSON-LD structured data — the SEO/AEO layer that lets search
# and AI answer engines understand and cite the pages.
RSpec.describe "Canonical + structured data", type: :request do
  it "emits a self-referencing canonical, stripped of query params" do
    get play_index_path(page: 2, hide_mine: "0")
    expect(response.body).to include(%(<link rel="canonical" href="#{play_index_url}">))
  end

  it "carries the sitewide WebSite schema on every page" do
    get root_path
    expect(response.body).to include('"@type":"WebSite"')
    expect(response.body).to include('application/ld+json')
  end

  it "marks a published puzzle as a Game" do
    puzzle = create(:published_puzzle, title: "Capital Cities")
    get play_path(puzzle.share_token)

    expect(response.body).to include('"@type":"Game"')
    expect(response.body).to include("Capital Cities")
  end

  it "leaves Game schema off an unlisted puzzle (it's noindex)" do
    puzzle = create(:puzzle, :complete, status: :unlisted)
    get play_path(puzzle.share_token)
    expect(response.body).not_to include('"@type":"Game"')
  end

  it "puts FAQ schema on how-to-play and HowTo on the guide" do
    get how_to_play_path
    expect(response.body).to include('"@type":"FAQPage"')

    get making_quartets_path
    expect(response.body).to include('"@type":"HowTo"')
  end

  it "escapes a puzzle title so it can't break out of the script tag" do
    puzzle = create(:published_puzzle, title: "</script><b>pwn</b>")
    get play_path(puzzle.share_token)

    # The raw injection never appears; the title survives unicode-escaped.
    expect(response.body).not_to include("</script><b>pwn</b>")
    expect(response.body).to include('\\u003c/script\\u003e')
  end
end
