require "rails_helper"

# Owner dashboard interactions that only really run in a browser.
RSpec.describe "Your puzzles dashboard", type: :system, js: true do
  let(:user) { create(:user) }
  before { login_as(user, scope: :user) }

  it "unpublishes a puzzle from the bottom-corner link after confirming" do
    puzzle = create(:published_puzzle, user: user, title: "Take It Down")

    visit puzzles_path
    accept_confirm("Are you sure you want to unpublish Take It Down?") do
      click_link "Unpublish?"
    end

    # The row re-renders as a draft (the Unpublish link is gone).
    expect(page).to have_no_link("Unpublish?")
    expect(puzzle.reload).to be_draft
  end
end
