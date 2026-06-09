require "rails_helper"

# Public, no-login play surface. Anyone can browse published puzzles and open one
# by its share token; drafts and bad tokens 404. An anonymous player cookie is
# minted on the way in so Phase 4 stats can attribute plays without accounts.
RSpec.describe "Play (public)", type: :request do
  describe "GET /play (index)" do
    it "is open to anyone and lists only published puzzles" do
      published = create(:published_puzzle, title: "Out in the world")
      draft     = create(:puzzle, title: "Still cooking", status: :draft)

      get play_index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Out in the world")
      expect(response.body).not_to include("Still cooking")
    end
  end

  describe "GET /p/:share_token (show)" do
    it "serves a published puzzle to an anonymous visitor" do
      puzzle = create(:published_puzzle, title: "Playable")

      get play_path(puzzle.share_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Playable")
    end

    it "mints an anonymous player cookie" do
      puzzle = create(:published_puzzle)

      get play_path(puzzle.share_token)

      expect(response.cookies["player_token"]).to be_present
    end

    it "404s a draft — it isn't public yet" do
      puzzle = create(:puzzle, :complete, status: :draft)

      get play_path(puzzle.share_token)

      expect(response).to have_http_status(:not_found)
    end

    it "404s an unknown token" do
      get play_path("nope-not-a-real-token")

      expect(response).to have_http_status(:not_found)
    end

    it "needs no login" do
      puzzle = create(:published_puzzle)

      get play_path(puzzle.share_token)

      expect(response).not_to redirect_to(new_user_session_path)
    end
  end
end
