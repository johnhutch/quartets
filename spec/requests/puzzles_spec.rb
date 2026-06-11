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
      expect(puzzle).to be_draft
      expect(puzzle.user).to be_nil
      expect(puzzle.creator_token).to be_present
      expect(response).to redirect_to(edit_puzzle_path(puzzle))
    end

    it "scopes the dashboard to the visitor's own cookie-owned puzzles" do
      post puzzles_path, params: { puzzle: { title: "Mine anon" } } # mints my cookie
      create(:puzzle, user: nil, creator_token: "someone-else", title: "Not mine")

      get puzzles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mine anon")
      expect(response.body).not_to include("Not mine")
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
      mine.update!(status: :draft)
      %i[blue green yellow purple].each_with_index do |color, i|
        mine.groups.create!(color: color, description: color.to_s, words: %w[a b c d], position: i)
      end

      patch publish_puzzle_path(mine)

      expect(mine.reload).to be_published
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
        expect(response.body).to include("My Puzzle")
        expect(response.body).not_to include("Their Puzzle")
        expect(response.body).not_to match(/you've made so far/i) # claim CTA is anon-only
      end
    end

    describe "POST /puzzles" do
      it "creates a draft owned by me and opens its editor" do
        expect {
          post puzzles_path, params: { puzzle: { title: "Fresh" } }
        }.to change(Puzzle, :count).by(1)

        puzzle = Puzzle.last
        expect(puzzle).to be_draft
        expect(puzzle.user).to eq(user)
        expect(response).to redirect_to(edit_puzzle_path(puzzle))
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

        expect(Puzzle.last).to be_draft
        expect(response).to redirect_to(edit_puzzle_path(Puzzle.last))
      end
    end

    describe "PATCH /puzzles/:id/publish" do
      it "publishes a complete draft" do
        puzzle = create(:puzzle, :complete, user: user, status: :draft)

        patch publish_puzzle_path(puzzle)

        expect(puzzle.reload).to be_published
        expect(response).to redirect_to(puzzles_path)
      end

      it "refuses to publish an incomplete draft" do
        puzzle = create(:puzzle, user: user, status: :draft) # no groups

        patch publish_puzzle_path(puzzle)

        expect(puzzle.reload).to be_draft
        expect(response).to have_http_status(:unprocessable_content)
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
