require "rails_helper"

# Static info pages + the site-wide footer (rendered in the layout, so it rides
# along on every page).
RSpec.describe "Static pages + footer", type: :request do
  describe "GET /privacy" do
    it "is public and spells out that we don't collect personal data" do
      get "/privacy"

      expect(response).to have_http_status(:ok)
      expect(response).not_to redirect_to(new_user_session_path)
      expect(response.body).to match(/privacy/i)
      expect(response.body).to match(/don'?t (collect|sell|track)/i)
    end
  end

  describe "GET /how-to-play" do
    it "is public and explains the rules" do
      get how_to_play_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/how to play/i)
      expect(response.body).to match(/four (mistakes|groups)/i)
    end
  end

  describe "GET /making-quartets" do
    it "is public and lays out what makes a good puzzle" do
      get making_quartets_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/good quartet/i)
      expect(response.body).to match(/exactly one group/i)
    end
  end

  it "links how-to-play from the play page (top-left escape hatch)" do
    puzzle = create(:published_puzzle)
    get play_path(puzzle.share_token)
    expect(response.body).to include(how_to_play_path)
  end

  describe "the site footer" do
    # The homepage fronts its own footer-as-section; every other page gets the
    # global one. The archive is a representative sub-page.
    it "rides along sub-pages with credit, socials, license, privacy, and the NYT disclaimer" do
      get play_index_path

      expect(response.body).to include("l-footer")
      expect(response.body).to include("johnhutch.com")          # created-by credit
      expect(response.body).to include("github.com/johnhutch")   # @johnhutch
      expect(response.body).to include("swiftkickweb.com")
      expect(response.body).to include(privacy_path)
      expect(response.body).to include("Creative Commons")
      expect(response.body).to match(/not affiliated with the new york times/i)
    end
  end
end
