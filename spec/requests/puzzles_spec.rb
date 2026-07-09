require "rails_helper"

RSpec.describe "Puzzles", type: :request do
  let(:user) { create(:user) }

  # Creation is public now (ADR-0005) — no login wall. A logged-out author owns
  # their work through a signed creator_token cookie until they claim it.
  describe "anonymous authoring" do
    it "lets a logged-out visitor create a puzzle owned by their cookie" do
      expect {
        post puzzles_path, params: { puzzle: { title: "Anon draft" } }
      }.to change(Puzzle, :count).by(1)

      puzzle = Puzzle.last
      expect(puzzle).to be_unlisted
      expect(puzzle.user).to be_nil
      expect(puzzle.creator_token).to be_present
      expect(response).to redirect_to(puzzles_path)
    end

    it "scopes the dashboard to the visitor's own cookie-owned puzzles" do
      post puzzles_path, params: { puzzle: { title: "Mine anon" } } # mints my cookie
      create(:puzzle, user: nil, creator_token: "someone-else", title: "Not mine")

      get puzzles_path

      expect(response).to have_http_status(:ok)
      # Titles render as multicolor spans, so compare against the stripped text.
      text = Nokogiri::HTML(response.body).text
      expect(text).to include("Mine anon")
      expect(text).not_to include("Not mine")
    end

    it "won't reach a puzzle owned by a different cookie" do
      other = create(:puzzle, user: nil, creator_token: "someone-else")
      get edit_puzzle_path(other)
      expect(response).to have_http_status(:not_found)
    end

    describe "claim CTA on the dashboard" do
      it "nudges the visitor to claim the puzzles their cookie owns, with a count" do
        post puzzles_path, params: { puzzle: { title: "One" } }
        post puzzles_path, params: { puzzle: { title: "Two" } }

        get puzzles_path

        expect(response.body).to include("2 puzzles")
        expect(response.body).to match(/sign up/i)
        expect(response.body).to include(new_user_registration_path)
      end

      it "doesn't show the CTA before anything's been created" do
        get puzzles_path
        expect(response.body).not_to match(/you've made so far/i)
      end
    end

    it "publishes its own anonymous draft" do
      post puzzles_path, params: { puzzle: { title: "Anon" } } # mints my cookie
      mine = Puzzle.last
      mine.update!(status: :unlisted)
      %i[blue green yellow purple].each_with_index do |color, i|
        # Distinct words per group — a repeat would (rightly) block the publish.
        words = (1..4).map { |n| "#{color}#{n}" }
        mine.groups.create!(color: color, description: color.to_s, words: words, position: i)
      end

      patch publish_puzzle_path(mine)

      expect(mine.reload).to be_published
    end
  end

  describe "authoring form block order (easiest → hardest)" do
    it "renders a new form yellow, green, blue, purple" do
      get new_puzzle_path

      positions = %w[yellow green blue purple].map { |c| response.body.index("m-group--#{c}") }
      expect(positions).to all(be_present)
      expect(positions).to eq(positions.sort)
    end

    it "orders an existing puzzle's edit form by color, not stored position" do
      user = create(:user)
      sign_in user
      puzzle = create(:puzzle, :complete, user: user) # factory positions: blue,green,yellow,purple

      get edit_puzzle_path(puzzle)

      positions = %w[yellow green blue purple].map { |c| response.body.index("m-group--#{c}") }
      expect(positions).to eq(positions.sort)
    end
  end

  context "when signed in" do
    before { sign_in user }

    describe "GET /puzzles" do
      it "shows my puzzles and not anyone else's" do
        create(:puzzle, user: user, title: "My Puzzle")
        create(:puzzle, title: "Their Puzzle") # different user via factory

        get puzzles_path

        expect(response).to have_http_status(:ok)
        text = Nokogiri::HTML(response.body).text
        expect(text).to include("My Puzzle")
        expect(text).not_to include("Their Puzzle")
        expect(response.body).not_to match(/you've made so far/i) # claim CTA is anon-only
      end

      it "shows how my puzzles are doing out in the world (plays, crowd solve rate, ratings)" do
        mine = create(:published_puzzle, user: user)
        create(:attempt, puzzle: mine, solved: true,  quality: :hell_yeah, difficulty: :not_bad)
        create(:attempt, puzzle: mine, solved: false)

        get puzzles_path

        text = Nokogiri::HTML(response.body).text
        expect(text).to include("Out in the world")
        expect(text).to include("Plays")
        expect(text).to include("Crowd solve rate")
        expect(text).to include("50%")
        expect(response.body).to include("m-likes") # thumbs received
        expect(text).to include("Not bad")          # voted difficulty label
      end

      it "keeps the author block quiet while nobody's played my puzzles" do
        create(:puzzle, user: user, title: "Fresh")

        get puzzles_path

        expect(response.body).not_to include("Out in the world")
      end

      it "tags an incomplete puzzle 'Incomplete' and offers 'Finish' (the editor), no Publish" do
        puzzle = create(:puzzle, user: user, title: "WIP", status: :unlisted) # no groups

        get puzzles_path

        text = Nokogiri::HTML(response.body).text
        expect(text).to include("Incomplete")
        expect(response.body).to include(edit_puzzle_path(puzzle))
        expect(text).to include("Finish")
        expect(response.body).not_to include(publish_puzzle_path(puzzle)) # can't publish yet
      end

      it "tags a complete-but-unlisted puzzle 'Unlisted' and offers a real Publish plus a quiet Edit" do
        puzzle = create(:puzzle, :complete, user: user, status: :unlisted)

        get puzzles_path

        text = Nokogiri::HTML(response.body).text
        expect(text).to include("Unlisted")
        expect(response.body).to include(publish_puzzle_path(puzzle))
        expect(response.body).to include(play_url(puzzle.share_token)) # a share link, since it's playable by link
        expect(text).to match(/\bEdit\b/)
      end
    end

    describe "POST /puzzles" do
      it "creates a draft owned by me and returns to the dashboard" do
        expect {
          post puzzles_path, params: { puzzle: { title: "Fresh" } }
        }.to change(Puzzle, :count).by(1)

        puzzle = Puzzle.last
        expect(puzzle).to be_unlisted
        expect(puzzle.user).to eq(user)
        expect(response).to redirect_to(puzzles_path)
      end

      it "persists the four nested groups" do
        post puzzles_path, params: { puzzle: {
          title: "Nested",
          groups_attributes: {
            "0" => { color: "blue",   description: "B", words: %w[a b c d] },
            "1" => { color: "green",  description: "G", words: %w[e f g h] },
            "2" => { color: "yellow", description: "Y", words: %w[i j k l] },
            "3" => { color: "purple", description: "P", words: %w[m n o p] }
          }
        } }

        expect(Puzzle.last.groups.count).to eq(4)
      end

      it "saves a blank-titled draft — the title comes last in the form" do
        expect {
          post puzzles_path, params: { puzzle: { title: "" } }
        }.to change(Puzzle, :count).by(1)

        expect(Puzzle.last).to be_unlisted
        expect(response).to redirect_to(puzzles_path)
      end
    end

    describe "PATCH /puzzles/:id/publish" do
      it "publishes a complete draft and lands on its public board" do
        puzzle = create(:puzzle, :complete, user: user, status: :unlisted)

        patch publish_puzzle_path(puzzle)

        expect(puzzle.reload).to be_published
        expect(response).to redirect_to(play_path(puzzle.share_token, published: 1))
      end

      it "refuses to publish an incomplete draft" do
        puzzle = create(:puzzle, user: user, status: :unlisted) # no groups

        patch publish_puzzle_path(puzzle)

        expect(puzzle.reload).to be_unlisted
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "PATCH /puzzles/:id/unpublish" do
      it "pulls a published puzzle back to draft" do
        puzzle = create(:published_puzzle, user: user)

        patch unpublish_puzzle_path(puzzle)

        expect(puzzle.reload).to be_unlisted
        expect(response).to redirect_to(puzzles_path)
      end
    end

    describe "GET /puzzles pagination" do
      it "shows 10 per page, the rest on the next page" do
        # 11 puzzles, newest first by updated_at. The oldest spills to page 2.
        oldest = create(:puzzle, user: user, title: "Oldest one")
        oldest.update_column(:updated_at, 1.day.ago)
        10.times { |i| create(:puzzle, user: user, title: "Filler #{i}") }

        get puzzles_path
        expect(Nokogiri::HTML(response.body).text).not_to include("Oldest one")

        get puzzles_path(page: 2)
        expect(Nokogiri::HTML(response.body).text).to include("Oldest one")
      end
    end

    describe "DELETE /puzzles/:id" do
      it "removes my puzzle" do
        puzzle = create(:puzzle, user: user)
        expect { delete puzzle_path(puzzle) }.to change(Puzzle, :count).by(-1)
      end
    end

    describe "ownership" do
      it "won't reach another user's puzzle" do
        other = create(:puzzle) # belongs to a different user
        get edit_puzzle_path(other)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
