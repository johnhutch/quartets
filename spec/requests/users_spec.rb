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

  # Bylines everywhere link back to the creator's page when the puzzle has an
  # account owner; anonymous (cookie-owned) puzzles keep a plain-text byline.
  describe "byline links" do
    it "links the play page byline to the creator's page" do
      user = create(:user, email: "hutch@example.com")
      puzzle = create(:published_puzzle, user: user, author_name: "Hutch")

      get play_path(puzzle.share_token)

      expect(response.body).to include(user_page_path("hutch"))
    end

    it "links archive and jump-in bylines too" do
      user = create(:user, email: "hutch@example.com")
      create(:published_puzzle, user: user, author_name: "Hutch")

      get play_index_path
      expect(response.body).to include(user_page_path("hutch"))

      get root_path
      expect(response.body).to include(user_page_path("hutch"))
    end

    it "keeps an anonymous creator's byline plain" do
      create(:published_puzzle, user: nil, creator_token: "anon", author_name: "Mystery")

      get play_index_path

      expect(response.body).to include("Mystery")
      expect(response.body).not_to include("/u/")
    end
  end
end
