require "rails_helper"

# The superuser admin: a puzzles tab (every puzzle, owner-grade actions) and a
# users tab (accounts + last login + created/solved counts). 404 to anyone who
# isn't the superuser — the area doesn't advertise its existence.
RSpec.describe "Admin", type: :request do
  let(:superuser) { create(:user, :superuser, email: "boss@example.com") }

  describe "the gate" do
    it "404s signed-out visitors" do
      get admin_root_path
      expect(response).to have_http_status(:not_found)
    end

    it "404s ordinary signed-in users" do
      sign_in create(:user)
      get admin_puzzles_path
      expect(response).to have_http_status(:not_found)

      get admin_users_path
      expect(response).to have_http_status(:not_found)
    end

    it "lets a moderator into the puzzles tab but not the users tab" do
      sign_in create(:user, :moderator)

      get admin_puzzles_path
      expect(response).to have_http_status(:ok)

      get admin_users_path # user admin is superuser-only
      expect(response).to have_http_status(:not_found)
    end

    it "hides the Users tab from a moderator" do
      sign_in create(:user, :moderator)
      get admin_puzzles_path
      expect(response.body).to include(admin_puzzles_path)
      expect(response.body).not_to include(admin_users_path)
    end
  end

  describe "landing + tabs" do
    before { sign_in superuser }

    it "lands on the puzzles tab with both tabs present" do
      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_puzzles_path)
      expect(response.body).to include(admin_users_path)
    end
  end

  describe "puzzles tab" do
    before { sign_in superuser }

    it "lists everyone's puzzles with owner-grade action rows" do
      create(:published_puzzle, title: "Someone Elses", user: create(:user, email: "maker@example.com"))
      create(:puzzle, title: "Anon Draft", user: nil, creator_token: "tok")

      get admin_puzzles_path

      expect(response.body).to include("Someone Elses")
      expect(response.body).to include("Anon Draft")
      expect(response.body).to include("maker") # owner handle in the status line
      expect(response.body).to include("anonymous")
      expect(response.body).to include("Delete") # the owner-grade action cluster
    end

    it "surfaces flagged puzzles with a count and dismisses them" do
      puzzle = create(:published_puzzle, title: "Flagged One")
      create(:report, puzzle: puzzle, reporter_token: "a")
      create(:report, puzzle: puzzle, reporter_token: "b")

      get admin_puzzles_path
      expect(response.body).to include("2 reports") # badge on the row
      expect(response.body).to match(/1 quartet flagged/i) # top banner

      # Filtered view shows only flagged puzzles.
      create(:published_puzzle, title: "Clean One")
      get admin_puzzles_path(flagged: 1)
      expect(response.body).to include("Flagged One")
      expect(response.body).not_to include("Clean One")

      # Dismissing clears the flags (the puzzle itself stays).
      patch dismiss_reports_admin_puzzle_path(puzzle)
      expect(puzzle.reports.unresolved).to be_empty
      expect(puzzle.reload).not_to be_deleted
    end

    it "shows per-puzzle engagement: starts, abandons, time to first group" do
      puzzle = create(:published_puzzle, title: "Pulse Check")
      create(:event, puzzle: puzzle, player_token: "a")
      create(:event, puzzle: puzzle, player_token: "b")
      create(:attempt, puzzle: puzzle, player_token: "a", guesses: [
        { "words" => %w[w x y z], "colors" => %w[blue blue blue blue], "t" => 45_000 }
      ])

      get admin_puzzles_path

      expect(response.body).to include("2 starts")
      expect(response.body).to include("1 abandoned (50%)")
      expect(response.body).to include("first group ~0:45")
    end

    it "lists tombstoned puzzles and restores them" do
      gone = create(:published_puzzle, title: "Tombstoned")
      create(:attempt, puzzle: gone)
      gone.soft_delete!

      get admin_puzzles_path
      expect(response.body).to include("Tombstoned")
      expect(response.body).to include("Deleted")

      patch restore_puzzle_path(gone)
      expect(gone.reload).not_to be_deleted
    end

    it "paginates past ten puzzles" do
      create_list(:published_puzzle, 11)

      get admin_puzzles_path

      expect(response.body.scan("m-puzzle-list__item").size).to eq(10)
      expect(response.body).to include("Page 1 of 2")
    end
  end

  describe "users tab" do
    before { sign_in superuser }

    it "lists accounts with last login and created/solved counts" do
      maker = create(:user, email: "maker@example.com", current_sign_in_at: 2.days.ago)
      create(:published_puzzle, user: maker)
      solved = create(:published_puzzle)
      create(:attempt, puzzle: solved, user: maker, solved: true)
      create(:user, email: "lurker@example.com") # never signed in

      get admin_users_path

      expect(response.body).to include("maker@example.com")
      expect(response.body).to include("2 days ago")
      expect(response.body).to include("never")
      expect(response.body).to include(user_page_path("maker"))
    end
  end

  # The last-login column only means something if Devise trackable actually
  # records — proven with a real login POST from a signed-out session (the
  # Warden test helper would short-circuit authentication and skip the hook).
  it "records last-login data on real sign-ins (trackable)" do
    user = create(:user, email: "t@example.com", password: "password123")

    post user_session_path, params: { user: { email: "t@example.com", password: "password123" } }

    expect(user.reload.current_sign_in_at).to be_present
    expect(user.sign_in_count).to eq(1)
  end

  describe "owner-grade access to any puzzle" do
    before { sign_in superuser }

    it "edits and updates someone else's puzzle" do
      puzzle = create(:published_puzzle, title: "Not Mine", user: create(:user))

      get edit_puzzle_path(puzzle)
      expect(response).to have_http_status(:ok)

      patch puzzle_path(puzzle), params: { puzzle: { title: "Corrected" } }
      expect(puzzle.reload.title).to eq("Corrected")
    end

    it "unpublishes and deletes someone else's puzzle" do
      puzzle = create(:published_puzzle, user: create(:user))

      patch unpublish_puzzle_path(puzzle)
      expect(puzzle.reload).to be_unlisted

      expect { delete puzzle_path(puzzle) }.to change(Puzzle, :count).by(-1)
    end

    it "still 404s an ordinary user reaching for someone else's puzzle" do
      sign_in create(:user) # replaces the superuser session
      puzzle = create(:published_puzzle, user: create(:user))

      get edit_puzzle_path(puzzle)

      expect(response).to have_http_status(:not_found)
    end
  end
end
