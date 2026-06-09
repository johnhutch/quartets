require "rails_helper"

# Author-facing analytics: a puzzle's stats page is gated and owner-scoped, like
# the rest of the dashboard. Players never see it (they get their own cube).
RSpec.describe "Puzzle stats", type: :request do
  let(:user) { create(:user) }

  it "bounces an unauthenticated visitor to sign in" do
    puzzle = create(:published_puzzle, user: user)
    get stats_puzzle_path(puzzle)
    expect(response).to redirect_to(new_user_session_path)
  end

  context "when signed in" do
    before { sign_in user }

    it "shows the owner their puzzle's numbers" do
      puzzle = create(:published_puzzle, user: user, title: "Mine")
      create(:attempt, puzzle: puzzle, solved: true,  mistakes_count: 1)
      create(:attempt, puzzle: puzzle, solved: false, mistakes_count: 4)

      get stats_puzzle_path(puzzle)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mine")
      expect(response.body).to include("Total attempts")
      expect(response.body).to include("50%") # one solved of two
    end

    it "handles a puzzle nobody has played yet" do
      puzzle = create(:published_puzzle, user: user)
      get stats_puzzle_path(puzzle)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No one's played this yet")
    end

    it "won't show another user's puzzle stats" do
      other = create(:published_puzzle) # different owner
      get stats_puzzle_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end
end
