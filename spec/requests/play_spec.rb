require "rails_helper"

# Public, no-login play surface. Anyone can browse published puzzles and open one
# by its share token; drafts and bad tokens 404. An anonymous player cookie is
# minted on the way in so Phase 4 stats can attribute plays without accounts.
RSpec.describe "Play (public)", type: :request do
  describe "GET /play (index)" do
    it "is open to anyone and lists only published puzzles" do
      published = create(:published_puzzle, title: "Out in the world")
      draft     = create(:puzzle, title: "Still cooking", status: :unlisted)

      get play_index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Out in the world")
      expect(response.body).not_to include("Still cooking")
    end

    it "marks puzzles the logged-in player has already completed (ADR-0009)" do
      user = create(:user)
      sign_in user
      create(:published_puzzle, title: "Finished it").tap do |p|
        create(:attempt, puzzle: p, user: user, solved: true)
      end
      create(:published_puzzle, title: "Not yet")

      get play_index_path

      text = Nokogiri::HTML(response.body).text
      expect(response.body).to include("Finished it")
      expect(response.body).to include("Not yet")
      expect(text.scan(/Played/).size).to eq(1) # only the finished one is badged
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

    # Playability gates on completeness, not visibility (ADR-0008): a finished
    # puzzle plays for anyone with the link, listed or not. Only the "published"
    # flag controls whether it shows up on the public surfaces.
    it "serves a complete but unlisted puzzle to anyone with the link" do
      puzzle = create(:puzzle, :complete, status: :unlisted, title: "Link only")

      get play_path(puzzle.share_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Link only")
    end

    it "404s an incomplete puzzle for a stranger — there's nothing to play" do
      puzzle = create(:puzzle, status: :unlisted, title: "Half built") # no groups

      get play_path(puzzle.share_token)

      expect(response).to have_http_status(:not_found)
    end

    it "redirects the owner of an incomplete puzzle to the editor" do
      user = create(:user)
      sign_in user
      puzzle = create(:puzzle, user: user, status: :unlisted) # incomplete

      get play_path(puzzle.share_token)

      expect(response).to redirect_to(edit_puzzle_path(puzzle))
    end

    it "lets the owner preview their own complete-but-unlisted puzzle with share + publish CTAs" do
      user = create(:user)
      sign_in user
      unlisted = create(:puzzle, :complete, user: user, status: :unlisted)

      get play_path(unlisted.share_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Share the link with anyone")     # honest copy
      expect(response.body).to include(play_url(unlisted.share_token))   # the share link itself
      expect(response.body).to include(publish_puzzle_path(unlisted))    # publish CTA
    end

    it "celebrates a just-published puzzle (?published=1)" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle, user: user, title: "Yay")

      get play_path(puzzle.share_token, published: 1)

      expect(response.body).to include("is published!")
    end

    it "shows no banner on an ordinary published visit" do
      puzzle = create(:published_puzzle, title: "Plain")

      get play_path(puzzle.share_token)

      expect(response.body).not_to include("is published!")
      expect(response.body).not_to include("Share the link with anyone")
    end

    it "tells search engines not to index an unlisted puzzle (ADR-0008)" do
      puzzle = create(:puzzle, :complete, status: :unlisted, title: "Hidden gem")

      get play_path(puzzle.share_token)

      expect(response.body).to include('name="robots"')
      expect(response.body).to include("noindex")
    end

    it "lets search engines index a published puzzle" do
      puzzle = create(:published_puzzle)

      get play_path(puzzle.share_token)

      expect(response.body).not_to include("noindex")
    end

    context "when a logged-in player has already finished it (ADR-0009)" do
      it "shows their result + the answers instead of a replayable board" do
        user = create(:user)
        sign_in user
        puzzle = create(:published_puzzle, title: "One and done")
        create(:attempt, puzzle: puzzle, user: user, solved: true,
                         guesses: [{ "words" => %w[a b c d], "colors" => %w[blue blue blue blue] }])

        get play_path(puzzle.share_token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("The answers")             # solution revealed
        expect(response.body).not_to include('data-controller="game"') # no fresh board
      end

      it "still serves a fresh board to a logged-in player who hasn't played it" do
        user = create(:user)
        sign_in user
        puzzle = create(:published_puzzle)

        get play_path(puzzle.share_token)

        expect(response.body).to include('data-controller="game"')
      end

      it "never gates an author out of their own puzzle" do
        user = create(:user)
        sign_in user
        puzzle = create(:published_puzzle, user: user)
        create(:attempt, puzzle: puzzle, user: user, solved: true)

        get play_path(puzzle.share_token)

        expect(response.body).to include('data-controller="game"')
      end
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
