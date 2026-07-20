require "rails_helper"

# The save-game for an in-progress play (finished plays are Attempts). Keyed by
# account when there is one, else by the anonymous player_token — one saved game
# per player per puzzle.
RSpec.describe PlayState, type: :model do
  it "requires a player_token" do
    state = build(:play_state, player_token: nil)
    expect(state).not_to be_valid
  end

  it "allows an anonymous state (no user)" do
    expect(build(:play_state, user: nil)).to be_valid
  end

  it "keeps one saved game per account per puzzle" do
    existing = create(:play_state, user: create(:user))

    dup = build(:play_state, puzzle: existing.puzzle, user: existing.user)
    expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "keeps one saved game per anonymous token per puzzle" do
    existing = create(:play_state, user: nil)

    dup = build(:play_state, puzzle: existing.puzzle, user: nil, player_token: existing.player_token)
    expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe ".stale" do
    it "finds anonymous saves idle past the TTL — and only those" do
      old_anon   = create(:play_state, user: nil, updated_at: (PlayState::ANONYMOUS_TTL + 1.day).ago)
      fresh_anon = create(:play_state, user: nil, updated_at: 1.day.ago)
      # An account save never goes stale — resuming across sessions/devices is
      # the product promise for logged-in players.
      old_owned = create(:play_state, user: create(:user),
                                      updated_at: (PlayState::ANONYMOUS_TTL + 1.day).ago)

      expect(PlayState.stale).to contain_exactly(old_anon)
      expect(PlayState.stale).not_to include(fresh_anon, old_owned)
    end

    it "measures idleness from the last save, not creation" do
      # Started long ago but still being played — a fresh guess bumps updated_at.
      active = create(:play_state, user: nil, created_at: 2.months.ago, updated_at: 1.hour.ago)

      expect(PlayState.stale).not_to include(active)
    end
  end
end
