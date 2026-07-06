require "rails_helper"

# The front door is a launchpad, not a play surface (the old "today's puzzle"
# homepage is gone). No login wall, no embedded game. It fronts the two paths —
# make one / play one — surfaces a random handful of published puzzles to dive
# into, and still mints the anonymous player cookie like the play pages.
RSpec.describe "Home", type: :request do
  describe "GET / (root)" do
    it "is open to anyone — no login wall" do
      create(:published_puzzle)

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response).not_to redirect_to(new_user_session_path)
    end

    it "fronts both paths: make one and play one" do
      get root_path

      expect(response.body).to include(new_puzzle_path)  # Create CTA
      expect(response.body).to include(play_index_path)   # Play / archive CTA
    end

    it "surfaces published puzzles as jump-in links" do
      puzzle = create(:published_puzzle, title: "Front and center")

      get root_path

      expect(response.body).to include("Front and center")
      expect(response.body).to include(play_path(puzzle.share_token))
    end

    it "caps the jump-in strip at STRIP_SIZE" do
      create_list(:published_puzzle, HomeController::STRIP_SIZE + 2)

      get root_path

      expect(response.body.scan("m-titles__row").size).to eq(HomeController::STRIP_SIZE)
    end

    it "only surfaces published puzzles — never unlisted/incomplete ones" do
      create(:published_puzzle, title: "On the shelf")
      create(:puzzle, title: "Backbench") # unlisted, not playable from here

      get root_path

      expect(response.body).not_to include("Backbench")
    end

    it "does not embed a playable game" do
      create(:published_puzzle)

      get root_path

      expect(response.body).not_to include('data-controller="game"')
    end

    it "mints the anonymous player cookie, same as the play pages" do
      create(:published_puzzle)

      get root_path

      expect(response.cookies["player_token"]).to be_present
    end

    it "still renders cleanly with no published puzzles" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(new_puzzle_path)        # Create is always there
      expect(response.body).not_to include("m-titles__row")    # strip is hidden, no empty list
    end

    it "suppresses the global topbar but keeps a Primary nav landmark" do
      get root_path

      # The global nav bar is killed here (the auth chip may still borrow its
      # .l-topbar__btn button chrome — that's chrome, not the bar).
      expect(response.body).not_to include('<header class="l-topbar">')
      expect(response.body).to include('aria-label="Primary"') # the fork carries the landmark
    end

    context "the floating auth chip" do
      it "offers log-in and sign-up buttons when logged out, styled like the subpage topbar" do
        get root_path

        expect(response.body).to include("Log in")
        expect(response.body).to include(new_user_session_path)
        expect(response.body).to include(new_user_registration_path)
        expect(response.body.scan("l-topbar__btn").size).to be >= 2 # the shared button chrome
      end

      it "links to your stuff when signed in" do
        sign_in create(:user)

        get root_path

        expect(response.body).to include(puzzles_path)
        expect(response.body).not_to include("Log in")
      end
    end
  end
end
