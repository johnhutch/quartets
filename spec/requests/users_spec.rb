require "rails_helper"

# Public per-creator page (/u/:handle — the deferred D3 of ADR-0005): their
# published puzzles plus their play stats (solved, solve rate, trophy counts).
# Login-free, like every play surface.
RSpec.describe "User pages", type: :request do
  it "shows the user's published puzzles and stats" do
    user = create(:user, email: "hutch@example.com")
    create(:published_puzzle, user: user, title: "Public Work")
    puzzle = create(:published_puzzle, title: "Someone Elses")
    create(:attempt, puzzle: puzzle, user: user, solved: true)

    get user_page_path("hutch")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("hutch")
    expect(page_text).to include("Public Work")
    expect(response.body).to include("m-trophy-case") # trophy counts
    expect(response.body).to include("Solve rate")
  end

  it "never lists unlisted or incomplete puzzles" do
    user = create(:user, email: "hutch@example.com")
    create(:puzzle, :complete, user: user, status: :unlisted, title: "Link Only")
    create(:puzzle, user: user, title: "Half Baked")

    get user_page_path("hutch")

    expect(page_text).not_to include("Link Only")
    expect(page_text).not_to include("Half Baked")
  end

  it "404s an unknown handle" do
    get user_page_path("nobody-here")

    expect(response).to have_http_status(:not_found)
  end

  it "shows play counts without a query per puzzle (grouped, not N+1)" do
    def query_count_for(handle)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get user_page_path(handle) }
      count
    end

    one = create(:user, email: "one@example.com")
    create(:published_puzzle, user: one)
    many = create(:user, email: "many@example.com")
    4.times { |i| create(:published_puzzle, user: many, title: "P#{i}") }

    # A per-row attempts.count would grow the query count with the puzzle count;
    # the grouped count keeps it flat, so 1 puzzle and 4 puzzles cost the same.
    expect(query_count_for("many")).to eq(query_count_for("one"))
  end

  # Bylines everywhere link back to the creator's page when the puzzle has an
  # account owner; anonymous (cookie-owned) puzzles keep a plain-text byline.
  describe "byline links" do
    it "links the play page byline to the creator's page" do
      user = create(:user, email: "hutch@example.com")
      puzzle = create(:published_puzzle, user: user, author_name: "Hutch")

      get play_path(puzzle.share_token)

      expect(response.body).to include(user_page_path("hutch"))
    end

    # The browse surfaces (archive + jump-in) show the byline as plain text —
    # the whole card is the play link, so the /u/:handle link lives only on the
    # show page.
    it "shows the author on browse cards but leaves it unlinked" do
      user = create(:user, email: "hutch@example.com")
      create(:published_puzzle, user: user, author_name: "Hutch")

      get play_index_path
      expect(response.body).to include("Hutch")
      expect(response.body).not_to include(user_page_path("hutch"))

      get root_path
      expect(response.body).to include("Hutch")
      expect(response.body).not_to include(user_page_path("hutch"))
    end

    it "keeps an anonymous creator's show-page byline plain" do
      puzzle = create(:published_puzzle, user: nil, creator_token: "anon", author_name: "Mystery")

      get play_path(puzzle.share_token)

      expect(response.body).to include("Mystery")
      expect(response.body).not_to include("/u/")
    end
  end
end
