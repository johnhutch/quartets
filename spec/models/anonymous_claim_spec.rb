require "rails_helper"

# ADR-0025: no cookie outlives three months, so a cookie is a lease on your work
# rather than where it lives. This is the sweep that moves it somewhere durable.
RSpec.describe AnonymousClaim do
  let(:user) { create(:user) }
  let(:creator_token) { "creator-abc" }
  let(:player_token) { "player-abc" }

  def claim
    described_class.new(user: user, creator_token: creator_token,
                        player_token: player_token).call
  end

  describe "puzzles (ADR-0005)" do
    it "moves cookie-owned puzzles onto the account and spends the token" do
      puzzle = create(:puzzle, user: nil, creator_token: creator_token)

      claim

      expect(puzzle.reload.user).to eq(user)
      expect(puzzle.creator_token).to be_nil
    end

    it "leaves another author's puzzles alone" do
      theirs = create(:puzzle, user: nil, creator_token: "someone-else")

      claim

      expect(theirs.reload.user).to be_nil
    end
  end

  describe "attempts (ADR-0009's one-play cap is the constraint)" do
    let(:puzzle) { create(:published_puzzle) }

    it "moves anonymous plays onto the account" do
      attempt = create(:attempt, puzzle: puzzle, player_token: player_token, solved: true)

      claim

      expect(attempt.reload.user).to eq(user)
    end

    it "carries the rating and trophy that were already on the play" do
      attempt = create(:attempt, puzzle: puzzle, player_token: player_token,
                       solved: true, quality: :hell_yeah, difficulty: :cursed)

      claim

      expect(attempt.reload.user).to eq(user)
      expect(attempt.quality).to eq("hell_yeah")
      expect(attempt.difficulty).to eq("cursed")
    end

    # The partial unique index on (user_id, puzzle_id) means a blind update_all
    # would raise here.
    it "skips a puzzle the account has already played, without colliding" do
      mine = create(:attempt, puzzle: puzzle, user: user, player_token: "other-device")
      anonymous = create(:attempt, puzzle: puzzle, player_token: player_token)

      expect { claim }.not_to raise_error

      expect(anonymous.reload.user).to be_nil # left anonymous, not deleted
      expect(mine.reload.user).to eq(user)
      expect(puzzle.attempts.count).to eq(2) # both still count in the puzzle's stats
    end

    # Anonymous play was never capped, so one token can hold several plays of the
    # same puzzle — but the account can only hold one.
    it "claims only the earliest when the token played one puzzle repeatedly" do
      first = create(:attempt, puzzle: puzzle, player_token: player_token,
                     created_at: 3.days.ago)
      second = create(:attempt, puzzle: puzzle, player_token: player_token,
                      created_at: 2.days.ago)
      third = create(:attempt, puzzle: puzzle, player_token: player_token,
                     created_at: 1.day.ago)

      expect { claim }.not_to raise_error

      expect(first.reload.user).to eq(user)
      expect(second.reload.user).to be_nil
      expect(third.reload.user).to be_nil
    end

    it "claims across several puzzles in one sweep" do
      others = create_list(:published_puzzle, 3)
      attempts = others.map { |p| create(:attempt, puzzle: p, player_token: player_token) }

      claim

      expect(attempts.map { |a| a.reload.user }).to all(eq(user))
    end

    it "leaves another player's attempts alone" do
      theirs = create(:attempt, puzzle: puzzle, player_token: "someone-else")

      claim

      expect(theirs.reload.user).to be_nil
    end
  end

  describe "mid-game saves (ADR-0022)" do
    let(:puzzle) { create(:published_puzzle) }

    it "moves an anonymous save onto the account so it resumes anywhere" do
      state = create(:play_state, puzzle: puzzle, user: nil, player_token: player_token)

      claim

      expect(state.reload.user).to eq(user)
    end

    it "leaves the anonymous save alone when the account already has one" do
      create(:play_state, puzzle: puzzle, user: user, player_token: "other-device")
      anonymous = create(:play_state, puzzle: puzzle, user: nil, player_token: player_token)

      expect { claim }.not_to raise_error
      expect(anonymous.reload.user).to be_nil
    end
  end

  describe "reports (ADR-0020)" do
    it "puts a name to a flag raised anonymously" do
      report = create(:report, user: nil, reporter_token: player_token)

      claim

      expect(report.reload.user).to eq(user)
    end
  end

  describe "with nothing to claim" do
    it "no-ops when neither cookie is set" do
      expect {
        described_class.new(user: user, creator_token: nil, player_token: nil).call
      }.not_to raise_error
    end

    it "no-ops when the tokens are blank strings" do
      expect {
        described_class.new(user: user, creator_token: "", player_token: "").call
      }.not_to raise_error
    end

    it "is idempotent — a second sweep changes nothing" do
      puzzle = create(:published_puzzle)
      attempt = create(:attempt, puzzle: puzzle, player_token: player_token)

      claim
      expect { claim }.not_to raise_error

      expect(attempt.reload.user).to eq(user)
      expect(user.attempts.count).to eq(1)
    end
  end
end
