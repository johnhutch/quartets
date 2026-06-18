require "rails_helper"

# The game beacons here on the first tile tap. Anonymous and login-free — the
# event is tied to the player's signed cookie token, same gate as attempts#create
# (any complete puzzle records; incomplete/unknown → 404). This is what makes a
# started-but-abandoned game detectable later (a game_started with no finishing
# Attempt), so we record the start even though nothing's displayed yet.
RSpec.describe "Events", type: :request do
  describe "POST /p/:share_token/events" do
    it "records a game_started event tied to the puzzle and player" do
      puzzle = create(:published_puzzle)

      expect {
        post play_events_path(puzzle.share_token), as: :json
      }.to change(Event, :count).by(1)

      event = Event.last
      expect(response).to have_http_status(:created)
      expect(event).to be_game_started
      expect(event.puzzle).to eq(puzzle)
      expect(event.player_token).to be_present
      expect(event.occurred_at).to be_present
    end

    it "attributes the event to the account when signed in" do
      user = create(:user)
      sign_in user
      puzzle = create(:published_puzzle)

      post play_events_path(puzzle.share_token), as: :json

      expect(Event.last.user).to eq(user)
    end

    it "reuses the same player token the attempt recorder uses" do
      puzzle = create(:published_puzzle)

      post play_events_path(puzzle.share_token), as: :json
      start_token = Event.last.player_token

      post play_attempts_path(puzzle.share_token),
           params: { attempt: { solved: false, mistakes_count: 4 } }, as: :json

      expect(Attempt.last.player_token).to eq(start_token)
    end

    it "records against a complete unlisted puzzle (shared by link)" do
      puzzle = create(:puzzle, :complete, status: :unlisted)

      expect {
        post play_events_path(puzzle.share_token), as: :json
      }.to change(Event, :count).by(1)
    end

    it "won't record against an incomplete puzzle — there's nothing to play" do
      puzzle = create(:puzzle, status: :unlisted) # no groups

      post play_events_path(puzzle.share_token), as: :json

      expect(response).to have_http_status(:not_found)
      expect(Event.count).to eq(0)
    end

    it "404s an unknown token" do
      post play_events_path("nope"), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
