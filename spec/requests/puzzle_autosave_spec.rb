require "rails_helper"

# The non-negotiable: drafts auto-save half-finished so the iOS back button can
# never eat work in progress. The form is answers-first with the title at the
# bottom, so a partial draft routinely has groups but no title yet — saving has
# to tolerate that and reload intact.
RSpec.describe "Puzzle auto-save", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  describe "POST /puzzles (first auto-save of a brand-new puzzle)" do
    it "creates an untitled draft from a partial first save" do
      expect {
        post puzzles_path, params: {
          autosave: "1",
          puzzle: {
            title: "",
            groups_attributes: {
              "0" => { color: "blue",  description: "Animals", words: ["cat", "dog", "", ""] },
              "1" => { color: "green", description: "",        words: ["", "", "", ""] }
            }
          }
        }
      }.to change(Puzzle, :count).by(1)

      puzzle = Puzzle.last
      expect(puzzle).to be_unlisted
      expect(puzzle.title).to be_blank
    end

    it "answers quietly with the new puzzle's editor URL, no redirect" do
      post puzzles_path, params: { autosave: "1", puzzle: { title: "" } }

      expect(response).to have_http_status(:created)
      expect(response.headers["Location"]).to eq(edit_puzzle_path(Puzzle.last))
    end
  end

  describe "PATCH /puzzles/:id (subsequent auto-saves)" do
    it "persists a partially-filled puzzle across a reload" do
      puzzle = create(:puzzle, user: user, title: "Draft", status: :unlisted)

      patch puzzle_path(puzzle), params: {
        autosave: "1",
        puzzle: {
          title: "",
          groups_attributes: {
            "0" => { color: "blue",  description: "Animals", words: %w[cat dog owl fox] },
            "1" => { color: "green", description: "Colors",  words: ["red", "blue", "", ""] }
          }
        }
      }

      puzzle.reload
      expect(puzzle).to be_unlisted
      expect(puzzle.title).to be_blank

      blue  = puzzle.groups.find_by(color: :blue)
      green = puzzle.groups.find_by(color: :green)
      expect(blue.words).to eq(%w[cat dog owl fox])
      expect(green.filled_words).to eq(%w[red blue])
    end

    it "answers with no content and no flash, so the save stays invisible" do
      puzzle = create(:puzzle, user: user, status: :unlisted)

      patch puzzle_path(puzzle), params: { autosave: "1", puzzle: { author_name: "Hutch" } }

      expect(response).to have_http_status(:no_content)
    end

    it "still won't reach another user's puzzle" do
      other = create(:puzzle) # belongs to a different user
      patch puzzle_path(other), params: { autosave: "1", puzzle: { title: "Hijacked" } }
      expect(response).to have_http_status(:not_found)
    end
  end
end
