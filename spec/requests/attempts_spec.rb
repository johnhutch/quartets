require "rails_helper"

# The game posts a finished play here. Anonymous: the attempt is tied to the
# player's signed cookie token, no account needed. Only published puzzles record.
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

    it "reuses the same player token across plays (the anonymous identity)" do
      puzzle = create(:published_puzzle)

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: false, mistakes_count: 4 } }, as: :json
      first_token = Attempt.last.player_token

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: true, mistakes_count: 0 } }, as: :json

      expect(Attempt.last.player_token).to eq(first_token)
    end

    it "won't record against a draft" do
      puzzle = create(:puzzle, :complete, status: :draft)

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
