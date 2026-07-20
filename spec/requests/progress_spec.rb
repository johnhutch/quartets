require "rails_helper"

# Mid-game progress persistence: the game saves its guess log after every
# submit, so leaving a puzzle and coming back resumes the board instead of
# resetting it. Logged-in players are keyed by account (works across devices);
# anonymous players by their player_token cookie (works as long as the cookie
# lives). The saved log is server-derived like a finished attempt — words in,
# colors out — so a forged save can't rehydrate a nonsense board.
RSpec.describe "Progress", type: :request do
  # The published_puzzle factory's real answers (same table as attempts_spec).
  ANSWERS = {
    blue:   %w[cat dog owl fox],
    green:  %w[one two three four],
    yellow: %w[mercury venus mars earth],
    purple: %w[piano drums bass flute]
  }.freeze

  def save_progress(puzzle, guesses, elapsed_ms: 5_000)
    put play_progress_path(puzzle.share_token),
        params: { progress: { guesses: guesses, elapsed_ms: elapsed_ms } }, as: :json
  end

  describe "PUT /p/:share_token/progress" do
    it "saves an anonymous player's in-progress game against their cookie token" do
      puzzle = create(:published_puzzle)

      expect {
        save_progress(puzzle, [{ words: ANSWERS[:blue] }, { words: %w[cat one mars piano] }])
      }.to change(PlayState, :count).by(1)

      expect(response).to have_http_status(:no_content)
      state = PlayState.last
      expect(state.puzzle).to eq(puzzle)
      expect(state.user_id).to be_nil
      expect(state.player_token).to be_present
      expect(state.elapsed_ms).to eq(5_000)
      # Colors are derived server-side from the puzzle, never trusted from the client.
      expect(state.guesses.first["colors"]).to eq(%w[blue blue blue blue])
      expect(state.guesses.second["colors"]).to eq(%w[blue green yellow purple])
    end

    it "upserts — a second save replaces the first, not stacks a new row" do
      puzzle = create(:published_puzzle)

      save_progress(puzzle, [{ words: ANSWERS[:blue] }])
      expect {
        save_progress(puzzle, [{ words: ANSWERS[:blue] }, { words: ANSWERS[:green] }], elapsed_ms: 9_000)
      }.not_to change(PlayState, :count)

      state = PlayState.last
      expect(state.guesses.size).to eq(2)
      expect(state.elapsed_ms).to eq(9_000)
    end

    it "saves a signed-in player's game against the account" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle)

      save_progress(puzzle, [{ words: ANSWERS[:blue] }])

      expect(PlayState.last.user).to eq(user)
    end

    it "rejects guesses that aren't real puzzle words" do
      puzzle = create(:published_puzzle)

      save_progress(puzzle, [{ words: %w[not real puzzle words] }])

      expect(response).to have_http_status(:unprocessable_content)
      expect(PlayState.count).to eq(0)
    end

    it "rejects a finished log — game over records via attempts, not progress" do
      puzzle = create(:published_puzzle)

      winning = ANSWERS.values.map { |words| { words: words } }
      save_progress(puzzle, winning)

      expect(response).to have_http_status(:unprocessable_content)
      expect(PlayState.count).to eq(0)
    end

    it "404s an incomplete puzzle, same as the play gate" do
      puzzle = create(:puzzle) # no groups — not playable

      save_progress(puzzle, [])

      expect(response).to have_http_status(:not_found)
    end

    it "refuses the owner — they don't play their own puzzle" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle, user: user)

      save_progress(puzzle, [{ words: ANSWERS[:blue] }])

      expect(response).to have_http_status(:not_found)
      expect(PlayState.count).to eq(0)
    end
  end

  describe "rehydration on GET /p/:share_token" do
    it "feeds the saved game back to the board" do
      puzzle = create(:published_puzzle)

      save_progress(puzzle, [{ words: ANSWERS[:blue] }])
      get play_path(puzzle.share_token)

      expect(response.body).to include("data-game-saved-value")
      expect(response.body).to include("cat")
      expect(response.body).to include("elapsedMs")
    end

    it "renders a fresh board when nothing is saved" do
      puzzle = create(:published_puzzle)

      get play_path(puzzle.share_token)

      expect(response.body).not_to include("elapsedMs")
    end

    it "hands a signed-in player the game they started anonymously" do
      user = create(:user)
      puzzle = create(:published_puzzle)

      save_progress(puzzle, [{ words: ANSWERS[:blue] }]) # anonymous — cookie only
      sign_in user
      get play_path(puzzle.share_token)

      expect(response.body).to include("data-game-saved-value")
      expect(response.body).to include("elapsedMs")
      expect(PlayState.last.user).to eq(user) # claimed onto the account
    end
  end

  describe "finishing the game" do
    it "clears the saved state once the play records" do
      puzzle = create(:published_puzzle)

      save_progress(puzzle, [{ words: ANSWERS[:blue] }])
      post play_attempts_path(puzzle.share_token), params: {
        attempt: { guesses: ANSWERS.values.map { |words| { words: words } } }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(PlayState.count).to eq(0)
    end
  end
end
