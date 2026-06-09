require "rails_helper"

# JSON export is an author tool: gated and owner-scoped (like stats), and it
# downloads as a file. Public play never exposes a puzzle's answers this way.
RSpec.describe "Puzzle export", type: :request do
  let(:user) { create(:user) }

  it "bounces an unauthenticated visitor to sign in" do
    puzzle = create(:published_puzzle, user: user)
    get export_puzzle_path(puzzle)
    expect(response).to redirect_to(new_user_session_path)
  end

  context "when signed in" do
    before { sign_in user }

    it "downloads the owner's puzzle as JSON" do
      puzzle = create(:published_puzzle, user: user, title: "Grab Me")

      get export_puzzle_path(puzzle)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(response.headers["Content-Disposition"]).to include('attachment', 'grab-me.json')

      body = JSON.parse(response.body)
      expect(body["title"]).to eq("Grab Me")
      expect(body["groups"].size).to eq(4)
    end

    it "won't export another user's puzzle" do
      other = create(:published_puzzle) # different owner
      get export_puzzle_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end
end
