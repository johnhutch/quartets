require "rails_helper"

# Owner dashboard interactions that only really run in a browser.
RSpec.describe "Your puzzles dashboard", type: :system, js: true do
  let(:user) { create(:user) }
  before { login_as(user, scope: :user) }

  it "makes a published puzzle unlisted from the bottom-corner link after confirming" do
    puzzle = create(:published_puzzle, user: user, title: "Take It Down")

    visit puzzles_path
    accept_confirm("Make Take It Down unlisted? The link still works, it just won't be listed.") do
      click_link "Make unlisted"
    end

    # The row re-renders as unlisted (the "Make unlisted" link is gone).
    expect(page).to have_no_link("Make unlisted")
    expect(puzzle.reload).to be_unlisted
  end
end
