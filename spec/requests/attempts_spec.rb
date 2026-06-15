require "rails_helper"

# The game posts a finished play here. Anonymous: the attempt is tied to the
# player's signed cookie token, no account needed. Any *complete* puzzle records,
# matching the play gate (ADR-0008) — incomplete ones (nothing to play) 404.
RSpec.describe "Attempts", type: :request do
  describe "POST /p/:share_token/attempts" do
    it "records a finished play, tied to the puzzle" do
      puzzle = create(:published_puzzle)

      expect {
        post play_attempts_path(puzzle.share_token), params: {
          attempt: {
            solved: true,
            mistakes_count: 1,
            guesses: [
              { words: %w[cat dog owl fox], colors: %w[blue blue blue blue] },
              { words: %w[cat dog owl one], colors: %w[blue blue blue green] }
            ]
          }
        }, as: :json
      }.to change(Attempt, :count).by(1)

      attempt = Attempt.last
      expect(response).to have_http_status(:created)
      expect(attempt.puzzle).to eq(puzzle)
      expect(attempt).to be_solved
      expect(attempt.mistakes_count).to eq(1)
      expect(attempt.player_token).to be_present
      expect(attempt.guesses.first["words"]).to eq(%w[cat dog owl fox])
      expect(attempt.guesses.first["colors"]).to eq(%w[blue blue blue blue])
    end

    it "returns the emoji cube for the just-finished play" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token), params: {
        attempt: {
          solved: true,
          mistakes_count: 1,
          guesses: [
            { words: %w[a b c d], colors: %w[blue blue blue blue] },
            { words: %w[a b c e], colors: %w[blue blue blue green] }
          ]
        }
      }, as: :json

      expect(response.parsed_body["cube"]).to eq("🟦🟦🟦🟦\n🟦🟦🟦🟩")
    end

    it "returns a full share block — title, cube, and a direct link to the puzzle" do
      puzzle = create(:published_puzzle, title: "Capital Cities")

      post play_attempts_path(puzzle.share_token), params: {
        attempt: {
          solved: true,
          mistakes_count: 0,
          guesses: [{ words: %w[a b c d], colors: %w[blue blue blue blue] }]
        }
      }, as: :json

      share = response.parsed_body["share"]
      expect(share).to include("Quartets — Capital Cities")
      expect(share).to include("🟦🟦🟦🟦")
      expect(share).to include(play_url(puzzle.share_token))
    end

    it "reuses the same player token across plays (the anonymous identity)" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: false, mistakes_count: 4 } }, as: :json
      first_token = Attempt.last.player_token

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json

      expect(Attempt.last.player_token).to eq(first_token)
    end

    it "records against a complete unlisted puzzle (shared by link)" do
      puzzle = create(:puzzle, :complete, status: :unlisted)

      expect {
        post play_attempts_path(puzzle.share_token),
             params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json
      }.to change(Attempt, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "won't record against an incomplete puzzle — there's nothing to play" do
      puzzle = create(:puzzle, status: :unlisted) # no groups

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "404s an unknown token" do
      post play_attempts_path("nope"),
           params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "rejects an impossible mistake count" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: false, mistakes_count: 99 } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
