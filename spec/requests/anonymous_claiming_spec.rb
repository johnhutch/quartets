require "rails_helper"

# ADR-0005, widened by ADR-0025: the moment an anonymous visitor authenticates,
# everything they did on a cookie gets reassigned to the account. Originally just
# authored puzzles; now plays and saves too, because no cookie outlives three
# months and the account is the only durable home for any of it.
RSpec.describe "Claiming anonymous work on auth", type: :request do
  let(:password) { "correct-horse-battery-staple" }

  # BotDetector treats a blank UA as a crawler and request specs send none, so the
  # funnel event we read the player_token back off of needs a browser-shaped one.
  # A `let`, not a constant: constants assigned inside a describe block land on
  # Object, and visit_logging_spec already owns the obvious name.
  let(:browser) do
    { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Safari/605.1" }
  end

  # The visitor's player_token as the *server* sees it — play#show logs a
  # puzzle_opened event keyed by it. The cookie itself is signed with an embedded
  # expiry, so it can't just be read back out of the jar.
  def play_anonymously(puzzle)
    get play_path(puzzle.share_token), headers: browser
    Event.puzzle_opened.last.player_token
  end

  describe "authored puzzles" do
    it "transfers cookie-owned puzzles to the account once signed in" do
      post puzzles_path, params: { puzzle: { title: "Anon work" } }
      puzzle = Puzzle.last
      expect(puzzle.user).to be_nil
      expect(puzzle.creator_token).to be_present

      user = create(:user)
      sign_in user
      get puzzles_path # any authenticated request triggers the claim

      expect(puzzle.reload.user).to eq(user)
      expect(puzzle.reload.creator_token).to be_nil
    end

    it "leaves other authors' puzzles alone" do
      not_mine = create(:puzzle, user: nil, creator_token: "someone-else")
      post puzzles_path, params: { puzzle: { title: "Mine" } } # mints my cookie

      user = create(:user)
      sign_in user
      get puzzles_path

      expect(not_mine.reload.user).to be_nil
      expect(not_mine.creator_token).to eq("someone-else")
    end
  end

  # The reason this matters: a cookie only ever knew about one browser. Playing in
  # a private window, or on a phone and then a laptop, left history stranded.
  describe "play history" do
    let(:puzzle) { create(:published_puzzle) }

    it "attaches plays to a brand-new account at signup" do
      attempt = create(:attempt, puzzle: puzzle, player_token: play_anonymously(puzzle),
                       solved: true)

      post user_registration_path,
           params: { user: { email: "new@example.com", password: password,
                             password_confirmation: password } }

      expect(attempt.reload.user).to eq(User.find_by(email: "new@example.com"))
    end

    it "attaches plays to an existing account at login" do
      user = create(:user, email: "back@example.com", password: password)
      attempt = create(:attempt, puzzle: puzzle, player_token: play_anonymously(puzzle),
                       solved: true)

      post user_session_path, params: { user: { email: user.email, password: password } }

      expect(attempt.reload.user).to eq(user)
    end

    it "claims a mid-game save so it resumes on another device" do
      state = create(:play_state, puzzle: puzzle, user: nil,
                     player_token: play_anonymously(puzzle))
      user = create(:user, email: "resume@example.com", password: password)

      post user_session_path, params: { user: { email: user.email, password: password } }

      expect(state.reload.user).to eq(user)
    end

    it "sweeps once per session, not on every request" do
      user = create(:user, email: "once@example.com", password: password)
      post user_session_path, params: { user: { email: user.email, password: password } }

      # A late-arriving anonymous row is not re-swept mid-session: the flag is set,
      # and nothing creates anonymous work for a signed-in visitor anyway.
      stray = create(:attempt, puzzle: puzzle, player_token: "unrelated")
      get puzzles_path

      expect(stray.reload.user).to be_nil
    end
  end

  describe "cookie lifespans" do
    it "gives the creator token the same three months as everything else" do
      post puzzles_path, params: { puzzle: { title: "Anon work" } }

      line = Array(response.headers["Set-Cookie"]).flat_map { |h| h.split("\n") }
                                                  .find { |l| l.start_with?("creator_token=") }
      expect(line).to be_present
      expect(Time.parse(line[/expires=([^;]+)/i, 1]))
        .to be_within(1.minute).of(Devise.remember_for.from_now)
    end
  end
end
