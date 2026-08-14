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

      expect(response.body.scan(/class="m-difficulty"/).size).to eq(1)
      expect(response.body).to include("m-likes")     # likes ride by the byline now
      expect(page_text).to include("2/4 difficulty")  # not_bad → 2nd of 4 on the meter
    end

    it "computes ratings for the puzzles actually shown, not a second random draw" do
      # With more published puzzles than the strip holds, the strip's RANDOM()
      # draw and the rating aggregate must agree. If the summaries are computed
      # from an independent roll, most shown rows lose their badge. Every puzzle
      # is rated, so after the fix all STRIP_SIZE shown rows carry a meter.
      (HomeController::STRIP_SIZE + 3).times do |i|
        p = create(:published_puzzle, title: "Rated #{i}")
        create(:attempt, puzzle: p, quality: :yeah, difficulty: :not_bad)
      end

      get root_path

      expect(response.body.scan(/class="m-difficulty"/).size).to eq(HomeController::STRIP_SIZE)
    end

    # A puzzle you've finished is a dead end here — opening it shows the
    # reconstructed result board, not a game (ADR-0012). The strip exists to hand
    # you something to play, so finished ones come out entirely rather than being
    # badged the way the archive badges them.
    it "leaves out the puzzles a signed-in player already finished" do
      user = create(:user)
      sign_in user
      played = create(:published_puzzle, title: "Been There")
      create(:published_puzzle, title: "Fresh Meat")
      create(:attempt, puzzle: played, user: user, solved: true)

      get root_path

      expect(page_text).to include("Fresh Meat")
      expect(page_text).not_to include("Been There")
    end

    # Anonymous plays are keyed by the player_token cookie, so the same rule has
    # to hold without an account — otherwise the strip keeps offering a visitor
    # the puzzle they just finished.
    it "leaves out the puzzles an anonymous player finished, by player_token" do
      played = create(:published_puzzle, title: "Anon Played This")
      create(:published_puzzle, title: "Still Untouched")

      get root_path # mints the cookie
      # The cookie is signed, so the raw jar value isn't the token the controller
      # reads — decode it the way the app does.
      token = ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash).signed[:player_token]
      create(:attempt, puzzle: played, player_token: token, solved: true)

      get root_path

      expect(page_text).to include("Still Untouched")
      expect(page_text).not_to include("Anon Played This")
    end

    it "brags at you when you've cleared everything on the site" do
      user = create(:user)
      sign_in user
      done = create(:published_puzzle, title: "The Last One")
      create(:attempt, puzzle: done, user: user, solved: true)

      get root_path

      expect(page_text).to match(/completed every puzzle we have/i)
      expect(page_text).to match(/go make some instead/i)
      expect(response.body).to include(new_puzzle_path) # somewhere to act on it
    end

    it "stays quiet when the site is simply empty, rather than claiming you cleared it" do
      user = create(:user)
      sign_in user

      get root_path

      expect(page_text).not_to match(/completed every puzzle/i)
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

    context "the manifesto footer" do
      # Manifesto headers used to be links styled without underlines — which
      # reads as plain text (a WCAG "links must look like links" problem). Links
      # live in the note copy now, where the CSS underlines them.
      it "keeps links in the body text, never on the headers" do
        get root_path

        doc = Nokogiri::HTML(response.body)
        expect(doc.css("a.m-manifesto__label")).to be_empty
        expect(doc.css(".m-manifesto__note a[href*='github.com/johnhutch']")).to be_present
      end

      # Legalese is not a column and not an appendage — it's one more bullet in
      # the list, sitting directly under "your puzzles are yours", carrying the
      # two links and no pitch. The bullets above already make the argument.
      it "carries terms + privacy as a Legalese item under 'your puzzles are yours'" do
        get root_path

        doc = Nokogiri::HTML(response.body)

        column_heads = doc.css(".m-manifesto__col > .m-manifesto__head")
        expect(column_heads.map(&:text)).not_to include(a_string_matching(/legalese/i))

        legalese = doc.css(".m-manifesto__item").find do |item|
          item.at_css(".m-manifesto__label")&.text&.match?(/legalese/i)
        end
        expect(legalese).to be_present

        # Placement, not just presence: last bullet of the ownership column.
        labels = legalese.parent.css(".m-manifesto__label").map(&:text)
        expect(labels.last(2)).to eq(["Your puzzles are yours", "Legalese"])

        hrefs = legalese.css(".m-manifesto__note a").map { |a| a["href"] }
        expect(hrefs).to contain_exactly(terms_path, privacy_path)
      end
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
