require "rails_helper"

# ADR-0005: the moment an anonymous author authenticates, the puzzles their
# creator_token cookie owns get reassigned to the account and the cookie is
# cleared. This is the bridge between anonymous create and a real account.
RSpec.describe "Claiming anonymous puzzles on auth", type: :request do
  it "transfers cookie-owned puzzles to the account once signed in" do
    # Author one anonymously — it lands on the creator_token cookie.
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
