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

  # Sign-in events are keyed by user, not by player: Devise's own pages don't
  # include AnonymousPlayer, so a first-ever signup has no player_token cookie
  # to read and there is nothing to require.
  it "lets a sign-in event go without a player token" do
    Event.event_types.keys.grep(/^signed_in/).each do |type|
      event = Event.new(event_type: type, user: build(:user))
      expect(event).to be_valid, "expected #{type} to be valid without a player_token"
    end
  end

  # Derived from the enum rather than from a second list, so a new event type is
  # covered here the moment it's added — and defaults to requiring a token.
  it "still requires a player token on every event that isn't user-keyed" do
    (Event.event_types.keys - Event::USER_KEYED_TYPES).each do |type|
      event = Event.new(event_type: type)
      expect(event).not_to be_valid, "expected #{type} to require a player_token"
    end
  end

  it "requires an event type" do
    expect(build(:event, event_type: nil)).not_to be_valid
  end

  it "lets the puzzle and user be absent (non-play events later)" do
    event = build(:event, puzzle: nil, user: nil)
    expect(event).to be_valid
  end
end
