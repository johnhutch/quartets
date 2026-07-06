require "rails_helper"

# A play-funnel event. The game_started beacon is the first writer; the model
# stays minimal (validations + an optional owner/puzzle) so the funnel can be
# derived off it later without touching Attempt.
RSpec.describe Event, type: :model do
  it "is valid as a game_started event tied to a puzzle and player token" do
    event = build(:event)
    expect(event).to be_valid
  end

  it "stamps occurred_at on its own when the caller doesn't" do
    event = Event.new(event_type: :game_started, player_token: "p-1")
    expect(event.occurred_at).to be_present
  end

  it "requires a player token" do
    event = build(:event, player_token: nil)
    expect(event).not_to be_valid
  end

  it "requires an event type" do
    expect(build(:event, event_type: nil)).not_to be_valid
  end

  it "lets the puzzle and user be absent (non-play events later)" do
    event = build(:event, puzzle: nil, user: nil)
    expect(event).to be_valid
  end
end
