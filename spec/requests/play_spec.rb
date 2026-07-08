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
      expect(page_text).to include("Out in the world")
      expect(page_text).not_to include("Still cooking")
    end

    it "flags themed puzzles with their tags viewable, leaves classics chip-less" do
      themed = create(:published_puzzle, title: "Nerds Only", specialized: true)
      themed.update!(tag_names: ["star wars", "trivia"])
      create(:published_puzzle, title: "Plain Classic")

      get play_index_path

      expect(response.body.scan(/m-themed--inline/).size).to eq(1)
      expect(page_text).to include("Themed")
      expect(page_text).to include("star-wars") # the theme is named inline, not hidden in a fold-out
    end

    it "shows the rating aggregate only on rated rows" do
      rated = create(:published_puzzle, title: "Crowd Pleaser")
      create(:attempt, puzzle: rated, quality: :hell_yeah, difficulty: :pretty_hard)
      create(:published_puzzle, title: "Unrated One")

      get play_index_path

      expect(response.body.scan(/class="m-difficulty"/).size).to eq(1)
      expect(response.body).to include("m-likes")     # likes ride by the byline now
      expect(page_text).to include("3/4 difficulty")  # pretty_hard → 3rd of 4 on the meter
    end

    it "marks puzzles the logged-in player has already completed (ADR-0009)" do
      user = create(:user)
      sign_in user
      create(:published_puzzle, title: "Finished it").tap do |p|
        create(:attempt, puzzle: p, user: user, solved: true)
      end
      create(:published_puzzle, title: "Not yet")

      get play_index_path

      expect(page_text).to include("Finished it")
      expect(page_text).to include("Not yet")
      expect(response.body.scan(/class="m-browse__done"/).size).to eq(1) # only the finished one gets the completed overlay
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

    # Owners never play their own puzzles — no self-earned trophies or stats.
    # Their own board renders revealed: every group in its solved state.
    it "shows the owner their own puzzle revealed instead of playable" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle, user: user)

      get play_path(puzzle.share_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('data-controller="game"')
      expect(response.body.scan(/m-game__group"/).size).to eq(4) # the 4 revealed rows
      # Still shareable from here — the whole point of visiting your own puzzle.
      expect(response.body).to include('data-action="share#share"')
      expect(response.body).to include(play_url(puzzle.share_token))
    end

    describe "themed flag on the show page" do
      it "shows the chip with the tags laid out inline" do
        puzzle = create(:published_puzzle, title: "Deep Cut", specialized: true)
        puzzle.update!(tag_names: ["star wars"])

        get play_path(puzzle.share_token)

        expect(response.body).to include("m-themed")
        expect(page_text).to include("Themed")
        expect(page_text).to include("star-wars")
      end

      it "shows nothing on a classic puzzle" do
        puzzle = create(:published_puzzle)

        get play_path(puzzle.share_token)

        expect(response.body).not_to include("m-themed")
      end
    end

    describe "rating aggregate on the show page" do
      it "renders thumbs + difficulty under the byline once votes exist" do
        puzzle = create(:published_puzzle)
        create(:attempt, puzzle: puzzle, quality: :yeah, difficulty: :cursed)
        create(:attempt, puzzle: puzzle, quality: :hell_yeah)

        get play_path(puzzle.share_token)

        expect(response.body).to include("m-ratemeta")
        expect(page_text).to include("3")            # 1 + 2 weighted thumbs
        expect(page_text).to include("4/4 difficulty") # cursed → maxed meter
      end

      it "renders nothing before anyone votes" do
        puzzle = create(:published_puzzle)

        get play_path(puzzle.share_token)

        expect(response.body).not_to include("m-ratemeta")
      end
    end

    # The author's description may hint at the trick (or spoil it outright), so
    # it hides behind a native <details> fold-out with a warning label.
    describe "description spoiler toggle" do
      it "offers the fold-out when the puzzle has a description" do
        puzzle = create(:published_puzzle, description: "Four kinds of Star Wars nonsense")

        get play_path(puzzle.share_token)

        expect(response.body).to include("m-description")
        expect(response.body).to include("View description")
        expect(response.body).to include("may contain hints or spoilers")
        expect(response.body).to include("Four kinds of Star Wars nonsense")
      end

      it "renders nothing without a description" do
        puzzle = create(:published_puzzle, description: nil)

        get play_path(puzzle.share_token)

        expect(response.body).not_to include("m-description")
        expect(response.body).not_to include("View description")
      end

      it "rides along on the finished-result view too" do
        user = create(:user)
        sign_in user
        puzzle = create(:published_puzzle, description: "Spoilery blurb")
        create(:attempt, puzzle: puzzle, user: user, solved: true)

        get play_path(puzzle.share_token)

        expect(response.body).to include("Spoilery blurb")
        expect(response.body).to include("View description")
      end
    end

    it "keeps the board playable for a non-owner" do
      puzzle = create(:published_puzzle)

      get play_path(puzzle.share_token)

      expect(response.body).to include('data-controller="game"')
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

    context "when a non-owner has already finished it (ADR-0009, ADR-0012)" do
      it "reconstructs the finished board instead of a replayable one (logged-in)" do
        user = create(:user)
        sign_in user
        puzzle = create(:published_puzzle, title: "One and done")
        create(:attempt, puzzle: puzzle, user: user, solved: true,
                         guesses: [{ "words" => %w[a b c d], "colors" => %w[blue blue blue blue] }])

        get play_path(puzzle.share_token)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Solved it")               # the win stamp / finished state
        # The on-page cube renders as palette-matched blocks (the raw emoji live
        # only in the copyable share text).
        expect(response.body.scan(/m-cube__cell--blue/).size).to eq(4)
        expect(response.body).not_to include('data-controller="game"') # no fresh board
      end

      it "shows a loss's finished state with the 'out of guesses' stamp" do
        user = create(:user)
        sign_in user
        puzzle = create(:published_puzzle)
        create(:attempt, puzzle: puzzle, user: user, solved: false, mistakes_count: 4)

        get play_path(puzzle.share_token)

        expect(response.body).to include("Out of guesses")
        expect(response.body).not_to include('data-controller="game"')
      end

      it "gates an anonymous player who finished it, keyed by the player_token (ADR-0012)" do
        puzzle = create(:published_puzzle)
        # An anonymous game-over records the attempt and sets the player_token cookie.
        post play_attempts_path(puzzle.share_token), as: :json, params: { attempt: {
          solved: true, mistakes_count: 0,
          guesses: [{ words: %w[a b c d], colors: %w[purple purple purple purple] }]
        } }

        get play_path(puzzle.share_token) # same cookie jar

        expect(response.body).to include("Solved it")
        expect(response.body).not_to include('data-controller="game"')
      end

      it "still serves a fresh board to a player who hasn't played it (logged-in or anon)" do
        puzzle = create(:published_puzzle)

        get play_path(puzzle.share_token) # anonymous, no prior attempt
        expect(response.body).to include('data-controller="game"')

        sign_in create(:user)
        get play_path(puzzle.share_token)
        expect(response.body).to include('data-controller="game"')
      end

      it "shows an author their own puzzle revealed, prior attempts or not" do
        user = create(:user)
        sign_in user
        puzzle = create(:published_puzzle, user: user)
        create(:attempt, puzzle: puzzle, user: user, solved: true) # from before the owner gate

        get play_path(puzzle.share_token)

        # The owner view wins: revealed board, no game, no attempt reconstruction.
        expect(response.body).to include('data-owner-view="true"')
        expect(response.body).not_to include('data-controller="game"')
        expect(response.body).not_to include('data-played="true"')
      end
    end

    context "archive filters (GET /play, signed in)" do
      let(:user) { create(:user) }
      before { sign_in user }

      it "hides your own puzzles by default" do
        create(:published_puzzle, user: user, title: "Mine Own")
        create(:published_puzzle, title: "Someone Elses")

        get play_index_path

        expect(page_text).not_to include("Mine Own")
        expect(page_text).to include("Someone Elses")
      end

      it "keeps anonymous puzzles visible while hiding mine (the NULL != id trap)" do
        create(:published_puzzle, user: nil, creator_token: "tok", title: "By A Ghost")
        create(:published_puzzle, user: user, title: "Mine Own")

        get play_index_path

        expect(page_text).to include("By A Ghost")
        expect(page_text).not_to include("Mine Own")
      end

      it "shows your own puzzles when hide_mine is unchecked" do
        create(:published_puzzle, user: user, title: "Mine Own")

        get play_index_path(hide_mine: "0")

        expect(page_text).to include("Mine Own")
      end

      it "marks completed puzzles with the completed overlay and dims the row" do
        puzzle = create(:published_puzzle, title: "Done Deal")
        create(:attempt, puzzle: puzzle, user: user, solved: true)

        get play_index_path

        expect(page_text).to include("Done Deal")
        expect(response.body).to include("m-browse__done")
        expect(response.body).to include("is-done")
      end

      it "hides completed puzzles when hide_completed is checked" do
        played = create(:published_puzzle, title: "Done Deal")
        create(:published_puzzle, title: "Fresh One")
        create(:attempt, puzzle: played, user: user, solved: true)

        get play_index_path(hide_completed: "1")

        expect(page_text).not_to include("Done Deal")
        expect(page_text).to include("Fresh One")
      end

      it "offers the filter fold-out only to visitors with something to filter" do
        get play_index_path
        expect(response.body).to include("m-filters")

        sign_out user
        get play_index_path # no account, no creator cookie → nothing to filter
        expect(response.body).not_to include("m-filters")
      end
    end

    # Anonymous authors own via the creator_token cookie (ADR-0005) and can't
    # play their own puzzles either (ADR-0015) — hide-mine covers them too.
    context "archive hide-mine for anonymous authors" do
      it "hides cookie-owned puzzles by default and offers the filter" do
        post puzzles_path, params: { puzzle: { title: "Scratch" } } # mints my creator cookie
        create(:published_puzzle, user: nil, creator_token: Puzzle.last.creator_token, title: "Anon Work")
        create(:published_puzzle, title: "Someone Elses")

        get play_index_path

        expect(page_text).not_to include("Anon Work")
        expect(page_text).to include("Someone Elses")
        expect(response.body).to include("m-filters")
        expect(response.body).not_to include("Hide completed") # completion is account-tracked
      end

      it "shows them when hide_mine is unchecked" do
        post puzzles_path, params: { puzzle: { title: "Scratch" } } # mints my creator cookie
        create(:published_puzzle, user: nil, creator_token: Puzzle.last.creator_token, title: "Anon Work")

        get play_index_path(hide_mine: "0")

        expect(page_text).to include("Anon Work")
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
