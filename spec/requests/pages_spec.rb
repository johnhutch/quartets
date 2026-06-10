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

  describe "the site footer" do
    it "rides along site-wide with credit, socials, license, privacy, and the NYT disclaimer" do
      get root_path

      expect(response.body).to include("l-footer")
      expect(response.body).to include("johnhutch.com")          # created-by credit
      expect(response.body).to include("github.com/johnhutch")   # @johnhutch
      expect(response.body).to include("swiftkickweb.com")
      expect(response.body).to include("/in/johnhutch-skw")      # linkedin
      expect(response.body).to include(privacy_path)
      expect(response.body).to include("Creative Commons")
      expect(response.body).to match(/not affiliated with the new york times/i)
    end
  end
end
