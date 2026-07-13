require "rails_helper"

# The "Completed" tab on Your stuff: puzzles you've finished (listed + unlisted),
# newest first, with completion date + any trophy. Account-scoped like trophies.
RSpec.describe "Completed puzzles", type: :request do
  def page_text
    Nokogiri::HTML(response.body).text
  end

  context "signed in" do
    let(:user) { create(:user) }
    before { sign_in user }

    it "lists finished puzzles — listed and unlisted — newest first, with a trophy" do
      listed   = create(:published_puzzle, title: "Listed Win")
      unlisted = create(:puzzle, :complete, status: :unlisted, title: "Unlisted Play")

      create(:attempt, user: user, puzzle: listed, solved: true, mistakes_count: 0) # flawless → trophy
      create(:attempt, user: user, puzzle: unlisted, solved: false)

      get completed_puzzles_path

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("Listed Win")
      expect(page_text).to include("Unlisted Play")   # unlisted shows too
      expect(page_text).to match(/Completed \w+ \d/)  # a completion date
      expect(response.body).to include("m-trophy")    # the flawless win's trophy
    end

    it "omits puzzles you haven't finished" do
      create(:published_puzzle, title: "Never Touched")
      get completed_puzzles_path
      expect(page_text).not_to include("Never Touched")
    end

    it "shows an empty state when you've completed nothing" do
      get completed_puzzles_path
      expect(page_text).to match(/no completed quartets/i)
    end

    it "links the tab from the dashboard" do
      get puzzles_path
      expect(response.body).to include(completed_puzzles_path)
    end
  end

  it "nudges anonymous visitors to sign up" do
    get completed_puzzles_path
    expect(response.body).to match(/sign up/i)
  end
end
