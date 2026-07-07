require "rails_helper"

# Post-play ratings: quality ("was this a good one?" — yeah / hell yeah) and
# difficulty (pretty easy → @!#?@!). One vote per finished play — the rating
# lives on the viewer's attempt, so logged-in and anonymous players both rate,
# and re-rating just changes their answer. Published puzzles only.
RSpec.describe "Ratings", type: :request do
  describe "PATCH /p/:share_token/rating" do
    it "records quality and difficulty on the signed-in player's attempt" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle)
      attempt = create(:attempt, puzzle: puzzle, user: user, solved: true)

      patch play_rating_path(puzzle.share_token), params: { quality: "hell_yeah" }, as: :json
      expect(response).to have_http_status(:no_content)

      patch play_rating_path(puzzle.share_token), params: { difficulty: "cursed" }, as: :json

      expect(attempt.reload.quality).to eq("hell_yeah")
      expect(attempt.difficulty).to eq("cursed")
    end

    it "re-rating replaces the earlier answer" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle)
      attempt = create(:attempt, puzzle: puzzle, user: user, solved: true)

      patch play_rating_path(puzzle.share_token), params: { difficulty: "pretty_easy" }, as: :json
      patch play_rating_path(puzzle.share_token), params: { difficulty: "pretty_hard" }, as: :json

      expect(attempt.reload.difficulty).to eq("pretty_hard")
    end

    it "rates an anonymous player's attempt through their cookie token" do
      puzzle = create(:published_puzzle)

      # Finishing the play mints the player_token cookie the rating rides on.
      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json
      patch play_rating_path(puzzle.share_token), params: { quality: "yeah" }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Attempt.last.quality).to eq("yeah")
    end

    it "refuses when the player hasn't finished the puzzle" do
      sign_in create(:user)
      puzzle = create(:published_puzzle)

      patch play_rating_path(puzzle.share_token), params: { quality: "yeah" }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "refuses on an unlisted puzzle — ratings are for published work" do
      user = create(:user)
      sign_in user
      puzzle = create(:puzzle, :complete, status: :unlisted)
      create(:attempt, puzzle: puzzle, user: user, solved: true)

      patch play_rating_path(puzzle.share_token), params: { quality: "yeah" }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "rejects a value that isn't on the menu" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle)
      create(:attempt, puzzle: puzzle, user: user, solved: true)

      patch play_rating_path(puzzle.share_token), params: { quality: "meh" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "the rating block" do
    it "appears on the revisit view with the player's picks marked" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle)
      create(:attempt, puzzle: puzzle, user: user, solved: true, quality: "hell_yeah")

      get play_path(puzzle.share_token)

      expect(response.body).to include("m-rating")
      expect(response.body).to include("Was this a good one?")
      expect(response.body).to include("How hard was it?")
      expect(response.body).to include("@!#?@!")
      expect(response.body.scan(/is-on/).size).to eq(1) # only hell-yeah is lit
    end

    it "rides along in the finished-play JSON for published puzzles" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json

      expect(response.parsed_body["rating"]).to include("m-rating")
    end

    it "stays out of unlisted plays" do
      puzzle = create(:puzzle, :complete, status: :unlisted)

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json

      expect(response.parsed_body["rating"]).to be_nil
    end
  end
end
