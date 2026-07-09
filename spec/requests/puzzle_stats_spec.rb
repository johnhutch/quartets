require "rails_helper"

# Author-facing analytics: a puzzle's stats page is owner-scoped (ADR-0005) —
# by account or creator_token. A visitor who doesn't own it can't see it (404),
# and players never reach it (they get their own cube).
RSpec.describe "Puzzle stats", type: :request do
  let(:user) { create(:user) }

  it "404s for a visitor who doesn't own the puzzle" do
    puzzle = create(:published_puzzle, user: user)
    get stats_puzzle_path(puzzle)
    expect(response).to have_http_status(:not_found)
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

    it "shows solve times, flawless count, trophies, ratings, and solve orders" do
      puzzle = create(:published_puzzle, user: user)
      clean_solve = %w[yellow green blue purple].map do |c|
        { "words" => %w[w x y z], "colors" => [c, c, c, c] }
      end
      create(:attempt, puzzle: puzzle, solved: true, mistakes_count: 0,
                       duration_ms: 222_000, guesses: clean_solve,
                       quality: :hell_yeah, difficulty: :pretty_hard)

      get stats_puzzle_path(puzzle)

      expect(response.body).to include("Median solve time")
      expect(response.body).to include("3:42")
      expect(response.body).to include("Flawless solves")
      expect(response.body).to include("Perfect") # trophy tally row
      expect(response.body).to include("m-likes") # thumbs received
      expect(response.body).to include("3/4 difficulty")
      expect(response.body).to include("Common solve orders")
    end

    it "skips the timing rows when no solve carries a duration" do
      puzzle = create(:published_puzzle, user: user)
      create(:attempt, puzzle: puzzle, solved: true, mistakes_count: 1)

      get stats_puzzle_path(puzzle)

      expect(response.body).not_to include("Median solve time")
    end

    it "renders common wrong guesses as color-coded chips, not a comma list" do
      puzzle = create(:published_puzzle, user: user)
      create(:attempt, puzzle: puzzle, solved: false, mistakes_count: 4, guesses: [
        { "words" => %w[CAT DOG OWL ONE], "colors" => %w[blue blue blue green] }
      ])

      get stats_puzzle_path(puzzle)

      expect(response.body).to include("m-guess-tiles__chip--blue")
      expect(response.body).to include("m-guess-tiles__chip--green")
      expect(response.body).to include("CAT")
      expect(response.body).not_to include("CAT, DOG") # commas are gone
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
