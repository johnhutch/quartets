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

      expect(page_text).to include("Front and center")
      expect(response.body).to include(play_path(puzzle.share_token))
    end

    it "caps the jump-in strip at STRIP_SIZE" do
      create_list(:published_puzzle, HomeController::STRIP_SIZE + 2)

      get root_path

      expect(response.body.scan("m-browse--strip").size).to eq(HomeController::STRIP_SIZE)
    end

    it "only surfaces published puzzles — never unlisted/incomplete ones" do
      create(:published_puzzle, title: "On the shelf")
      create(:puzzle, title: "Backbench") # unlisted, not playable from here

      get root_path

      expect(page_text).not_to include("Backbench")
    end

    # Themed puzzles used to be excluded from the strip outright (ADR-0010);
    # now the visible flag does the warning work, so they ride along flagged.
    it "includes themed (specialized) puzzles, flagged so people can dodge or chase them" do
      create(:published_puzzle, title: "For Everyone")
      themed = create(:published_puzzle, title: "Nerds Only", specialized: true)
      themed.update!(tag_names: ["star wars"])

      get root_path

      expect(page_text).to include("Nerds Only")
      expect(response.body.scan(/m-themed--inline/).size).to eq(1) # only the themed row
      expect(page_text).to include("star-wars")                   # the theme is named inline
    end

    # You can't play your own puzzles (ADR-0015), so a jump-in row for one is a
    # dead link to a revealed board. Filtered like the archive's hide-mine.
    it "leaves the signed-in visitor's own puzzles out of the strip" do
      user = create(:user)
      sign_in user
      create(:published_puzzle, user: user, title: "Mine Own")
      create(:published_puzzle, title: "Someone Elses")

      get root_path

      expect(page_text).not_to include("Mine Own")
      expect(page_text).to include("Someone Elses")
    end

    it "leaves an anonymous author's cookie-owned puzzles out of the strip too" do
      post puzzles_path, params: { puzzle: { title: "Scratch" } } # mints my creator cookie
      create(:published_puzzle, user: nil, creator_token: Puzzle.last.creator_token, title: "Anon Work")
      create(:published_puzzle, title: "Someone Elses")

      get root_path

      expect(page_text).not_to include("Anon Work")
      expect(page_text).to include("Someone Elses")
    end

    it "shows the rating aggregate on rated strip rows, like the archive does" do
      rated = create(:published_puzzle, title: "Crowd Pleaser")
      create(:attempt, puzzle: rated, quality: :yeah, difficulty: :not_bad)
      create(:published_puzzle, title: "Unrated One")

      get root_path

      expect(response.body.scan(/m-ratemeta"/).size).to eq(1)
      expect(page_text).to include("2/4 difficulty") # not_bad → 2nd of 4 on the meter
    end

    it "flags the ones a signed-in player already finished, like the archive does" do
      user = create(:user)
      sign_in user
      played = create(:published_puzzle, title: "Been There")
      create(:published_puzzle, title: "Fresh Meat")
      create(:attempt, puzzle: played, user: user, solved: true)

      get root_path

      expect(response.body.scan(/class="m-browse__done"/).size).to eq(1) # the completed overlay
      expect(response.body).to include("is-done")                        # the dimmed row
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
      expect(response.body).not_to include("m-browse--strip")  # strip is hidden, no empty list
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
