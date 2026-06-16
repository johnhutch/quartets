require "rails_helper"

# The front door: a public, login-free homepage that drops a visitor straight
# into a playable puzzle. Prefers a random featured puzzle; with none featured,
# falls back to a random unplayed published puzzle. Clear the whole board and it
# sends you off to make one.
RSpec.describe "Home", type: :request do
  describe "GET / (root)" do
    it "is open to anyone — no login wall" do
      create(:published_puzzle, :complete, featured: true)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response).not_to redirect_to(new_user_session_path)
    end

    it "drops the visitor into a playable featured puzzle" do
      create(:published_puzzle, title: "Front and center", featured: true)

      get root_path

      expect(response.body).to include("Front and center")
      # The board is wired to the game controller — its hook proves it's playable.
      expect(response.body).to include('data-controller="game"')
    end

    it "only ever surfaces featured puzzles" do
      create(:published_puzzle, title: "Spotlight", featured: true)
      create(:published_puzzle, title: "Backbench", featured: false)

      # Hit it a few times; an unfeatured puzzle must never sneak in.
      5.times do
        get root_path
        expect(response.body).not_to include("Backbench")
      end
    end

    it "falls back to a random unplayed puzzle when nothing is featured" do
      create(:published_puzzle, title: "Backbench", featured: false)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Backbench")
      expect(response.body).to include('data-controller="game"') # playable board, not an empty state
    end

    it "sends you to make one once you've cleared every published puzzle" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle, featured: false)
      create(:attempt, user: user, puzzle: puzzle, solved: true) # the only one, done

      get root_path

      expect(response.body).not_to include('data-controller="game"')
      expect(response.body).to match(/done them all/i)
      expect(response.body).to include(new_puzzle_path) # the "make one" CTA
    end

    it "shows the plain empty state when there are no published puzzles at all" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('data-controller="game"')
      expect(response.body).to include("Sign in")
    end

    it "mints the anonymous player cookie, same as the play pages" do
      create(:published_puzzle, featured: true)

      get root_path

      expect(response.cookies["player_token"]).to be_present
    end

    it "offers a 'Play More' link to the browse list in the nav" do
      get root_path

      expect(response.body).to include("Play More")
      expect(response.body).to include(play_index_path)
    end
  end
end
