require "rails_helper"

# ADR-0005, widened by ADR-0025: the moment an anonymous visitor authenticates,
# everything they did on a cookie gets reassigned to the account. Originally just
# authored puzzles; now plays and saves too, because no cookie outlives three
# months and the account is the only durable home for any of it.
RSpec.describe "Claiming anonymous work on auth", type: :request do
  let(:password) { "correct-horse-battery-staple" }

  # play_anonymously / browser_headers / expiry_of come from
  # spec/support/request_cookies.rb.

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

    # `except: :fetch` — deserializing an already-signed-in user on every later
    # request is not an authentication, so the sweep must not re-run there. Uses
    # this session's OWN player_token, so the only reason it stays unclaimed is
    # that no sweep happened; a token belonging to someone else would sit there
    # untouched either way and prove nothing.
    it "does not re-sweep on ordinary requests inside a session" do
      user = create(:user, email: "once@example.com", password: password)
      token = play_anonymously(puzzle)
      post user_session_path, params: { user: { email: user.email, password: password } }

      late = create(:attempt, puzzle: create(:published_puzzle), player_token: token)
      get puzzles_path

      expect(late.reload.user).to be_nil
    end
  end

  describe "cookie lifespans" do
    it "gives the creator token the same three months as everything else" do
      post puzzles_path, params: { puzzle: { title: "Anon work" } }

      expect(set_cookie_line("creator_token")).to be_present
      expect(expiry_of("creator_token"))
        .to be_within(1.minute).of(Rails.application.config.x.identity_lifespan.from_now)
    end

    # The cookie is the *only* key to an anonymous author's puzzles, published
    # ones included — `puzzles.user_id` is nil, so if it lapses, edit/unpublish/
    # delete/stats all 404 on a live listing with no way back. It used to slide
    # only inside PuzzlesController, so the ordinary thing to do after publishing
    # (share the link, watch it get played) let it die untouched.
    it "keeps sliding on the play surfaces, not just authoring pages" do
      post puzzles_path, params: { puzzle: { title: "Anon work" } }
      puzzle = Puzzle.last

      get play_index_path
      expect(expiry_of("creator_token"))
        .to be_within(1.minute).of(Rails.application.config.x.identity_lifespan.from_now)

      get play_path(puzzle.share_token)
      expect(expiry_of("creator_token")).to be_present
    end

    it "does not hand a creator token to someone who has only ever played" do
      get play_index_path

      expect(set_cookie_line("creator_token")).to be_nil
    end
  end
end
