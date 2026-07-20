require "rails_helper"

# The XML sitemap search + AI-citation crawlers use to discover the catalog.
# Only public, indexable URLs belong here — published puzzles, the static pages,
# and creator profiles; never unlisted/incomplete puzzles (they carry noindex).
RSpec.describe "Sitemap", type: :request do
  it "lists public URLs as valid XML" do
    published = create(:published_puzzle, user: create(:user, email: "maker@example.com"))
    unlisted  = create(:puzzle, :complete, status: :unlisted)
    incomplete = create(:puzzle) # no groups

    get "/sitemap.xml"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/xml")
    body = response.body

    # Public surfaces present.
    expect(body).to include(root_url)
    expect(body).to include(play_index_url)
    expect(body).to include(how_to_play_url)
    expect(body).to include(making_quartets_url)
    expect(body).to include(play_url(published.share_token))
    expect(body).to include(user_page_url(published.user.handle))

    # Non-public puzzles stay out.
    expect(body).not_to include(play_url(unlisted.share_token))
    expect(body).not_to include(play_url(incomplete.share_token))
  end

  it "only lists profiles for users who have published something" do
    author = create(:user, email: "has@example.com")
    create(:published_puzzle, user: author)
    create(:user, email: "empty@example.com") # no published puzzles

    get "/sitemap.xml"

    expect(response.body).to include(user_page_url("has"))
    expect(response.body).not_to include(user_page_url("empty"))
  end

  it "404s the speculative gzipped variant crawlers probe for" do
    # Bingbot requests /sitemap.xml.gz on spec (sitemaps.org allows a gzipped
    # sitemap; we don't offer one — the wire is already compressed by
    # Cloudflare via Accept-Encoding). Without format: false on the route this
    # matched with format "gz" and 500ed on the missing gzip template.
    get "/sitemap.xml.gz"

    expect(response).to have_http_status(:not_found)
  end
end
