require "rails_helper"

# Staying signed in, and the instrumentation that tells us whether people are.
#
# The bug this pins: stock Devise registration signs you in with a *session*
# cookie only, so a brand-new account was logged out as soon as the browser
# dropped the session — on iOS Safari, fast. Signing in already offered "Stay
# logged in"; signing up now means the same thing.
RSpec.describe "Session persistence", type: :request do
  let(:password) { "correct-horse-battery-staple" }

  # set_cookie_line / expiry_of / browser_headers / play_anonymously come from
  # spec/support/request_cookies.rb.
  def remember_cookie
    response.headers["Set-Cookie"].to_s[/remember_user_token=([^;]+)/, 1]
  end

  describe "POST /users (sign up)" do
    let(:params) do
      { user: { email: "fresh@example.com", password: password,
                password_confirmation: password } }
    end

    it "sets a remember cookie so the account survives the browser session" do
      post user_registration_path, params: params

      expect(User.find_by(email: "fresh@example.com")).to be_present
      expect(remember_cookie).to be_present
    end

    it "stamps remember_created_at on the new account" do
      post user_registration_path, params: params

      expect(User.find_by(email: "fresh@example.com").remember_created_at).to be_present
    end

    it "still permits display_name (ApplicationController's sanitizer survives the override)" do
      post user_registration_path,
           params: { user: params[:user].merge(display_name: "Fresh Face") }

      expect(User.find_by(email: "fresh@example.com").display_name).to eq("Fresh Face")
    end

    it "re-renders without a remember cookie when signup fails" do
      create(:user, email: "taken@example.com")

      post user_registration_path,
           params: { user: { email: "taken@example.com", password: password,
                             password_confirmation: password } }

      expect(remember_cookie).to be_blank
    end
  end

  describe "POST /users/sign_in" do
    let!(:user) { create(:user, email: "returning@example.com", password: password) }

    it "remembers when the box is ticked" do
      post user_session_path,
           params: { user: { email: user.email, password: password, remember_me: "1" } }

      expect(remember_cookie).to be_present
    end
  end

  describe "the remembered window" do
    it "lasts three months and slides with use" do
      expect(Devise.remember_for).to eq(3.months)
      expect(Devise.extend_remember_period).to be(true)
    end
  end

  # The player_token cookie used to be `permanent` — twenty years — so it outlived
  # every login by a mile, and PlayerCompletions kept rebuilding "your solved
  # puzzles" for someone the menu was correctly showing as logged out. The two
  # identities expire together now.
  describe "player_token lifespan" do
    let!(:user) { create(:user, email: "player@example.com", password: password) }

    it "matches the remembered login's own expiry, to the second" do
      post user_session_path,
           params: { user: { email: user.email, password: password, remember_me: "1" } }
      # Grabbed here because the remember cookie is only written at sign-in; the
      # player cookie is rewritten on every play-surface request.
      login_expiry = expiry_of("remember_user_token")

      get play_index_path

      expected = user.reload.remember_created_at + Devise.remember_for
      expect(expiry_of("player_token")).to be_within(2.seconds).of(expected)
      # And that really is when the login cookie goes, not a lookalike window.
      expect(login_expiry).to be_present
      expect(expiry_of("player_token")).to be_within(2.seconds).of(login_expiry)
    end

    # The example above can't tell "pinned to the login" from "slides from now":
    # the sign-in just happened, so both land on the same second. The difference
    # only shows for a returning player, whose remember cookie was minted a while
    # back and isn't refreshed mid-session. If the player token slid from *now* it
    # would start outliving the login — which is the orphan state coming back.
    it "does not outlive a login that was minted a while ago" do
      post user_session_path,
           params: { user: { email: user.email, password: password, remember_me: "1" } }
      user.update!(remember_created_at: 30.days.ago)

      get play_index_path

      expect(expiry_of("player_token"))
        .to be_within(1.minute).of(30.days.ago + Devise.remember_for)
      # Decisively earlier than a token that simply slid from now.
      expect(expiry_of("player_token")).to be < (Devise.remember_for.from_now - 20.days)
    end

    it "becomes a session cookie when the login is session-only" do
      post user_session_path,
           params: { user: { email: user.email, password: password, remember_me: "0" } }
      get play_index_path

      expect(set_cookie_line("player_token")).to be_present
      expect(expiry_of("player_token")).to be_nil # no expires= — dies with the browser
    end

    it "lasts remember_for for a visitor who has never logged in" do
      get play_index_path

      expect(expiry_of("player_token")).to be_within(1.minute).of(Devise.remember_for.from_now)
    end

    # Read the token the way the server sees it — play#show logs a puzzle_opened
    # event keyed by it. The raw cookie can't be compared directly: the expiry is
    # baked into the signed payload, so the bytes change every request even though
    # the token doesn't.
    it "keeps the same token across requests — only the expiry moves" do
      puzzle = create(:published_puzzle)

      get play_path(puzzle.share_token), headers: browser_headers
      first = Event.puzzle_opened.last.player_token
      get play_path(puzzle.share_token), headers: browser_headers

      expect(first).to be_present
      expect(Event.puzzle_opened.last.player_token).to eq(first)
    end

    it "is never permanent again" do
      get play_index_path

      expect(expiry_of("player_token")).to be < 1.year.from_now
    end
  end

  describe "DELETE /users/sign_out" do
    let!(:user) { create(:user, email: "leaving@example.com", password: password) }

    it "clears the player token along with the login" do
      post user_session_path,
           params: { user: { email: user.email, password: password, remember_me: "1" } }
      get play_index_path
      expect(cookies["player_token"]).to be_present

      delete destroy_user_session_path

      expect(cookies["player_token"]).to be_blank
      expect(cookies["remember_user_token"]).to be_blank
    end

    it "leaves no solved-puzzle identity behind — the orphan state is gone" do
      puzzle = create(:published_puzzle)
      get play_path(puzzle.share_token), headers: browser_headers
      create(:attempt, puzzle: puzzle, solved: true,
             player_token: Event.puzzle_opened.last.player_token)

      # While the token is alive, the archive knows the puzzle is solved.
      get play_index_path
      expect(page_text).to include("Your solved puzzles") # multicolored — assert text, not markup

      post user_session_path,
           params: { user: { email: user.email, password: password, remember_me: "1" } }
      delete destroy_user_session_path
      get play_index_path

      expect(page_text).not_to include("Your solved puzzles")
    end
  end

  # Session-health instrumentation — the Warden hook in
  # config/initializers/session_events.rb. Read by SessionStats.
  describe "sign-in events" do
    let!(:user) { create(:user, email: "measured@example.com", password: password) }

    it "records a password sign-in as signed_in" do
      expect {
        post user_session_path, params: { user: { email: user.email, password: password } }
      }.to change { Event.signed_in.count }.by(1)

      expect(Event.signed_in.last.user).to eq(user)
    end

    it "records a signup as signed_in — somebody typed credentials into a form" do
      expect {
        post user_registration_path,
             params: { user: { email: "brand@example.com", password: password,
                               password_confirmation: password } }
      }.to change { Event.signed_in.count }.by(1)
    end

    it "records nothing on a failed sign-in" do
      expect {
        post user_session_path, params: { user: { email: user.email, password: "wrong" } }
      }.not_to change(Event, :count)
    end

    it "does not fire again on ordinary requests within the session" do
      post user_session_path, params: { user: { email: user.email, password: password } }

      expect { get play_index_path }.not_to change(Event, :count)
    end

    it "records a remember-cookie sign-in as signed_in_remembered" do
      # Sign in with remember, drop only the session cookie, then come back — the
      # shape of a real returning visit, where the browser expired the session but
      # kept the remember cookie.
      post user_session_path,
           params: { user: { email: user.email, password: password, remember_me: "1" } }
      expect(remember_cookie).to be_present

      cookies.delete(Rails.application.config.session_options[:key])

      expect { get puzzles_path }.to change { Event.signed_in_remembered.count }.by(1)
      expect(response).to have_http_status(:ok) # actually signed in, not bounced
      expect(Event.signed_in_remembered.last.user).to eq(user)
    end
  end
end
