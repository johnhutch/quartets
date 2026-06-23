require "rails_helper"

# The archive (/play) hides your own quartets by default so you browse other
# people's work; the topbar toggle flips them back in. The checkbox auto-submits,
# so this needs a real browser.
RSpec.describe "Archive: hide my quartets", type: :system, js: true do
  let(:user) { create(:user) }

  before { login_as(user, scope: :user) }

  it "hides the author's own puzzles until they toggle them back on" do
    create(:published_puzzle, user: user, title: "Mine to hide")
    create(:published_puzzle, title: "Anothers puzzle")

    visit play_index_path

    # On by default: my puzzle is hidden, everyone else's shows. (The brutal theme
    # uppercases list text via CSS, so match case-insensitively.)
    expect(page).to have_content(/anothers puzzle/i)
    expect(page).to have_no_content(/mine to hide/i)
    expect(page).to have_field("Hide my quartets", checked: true)

    # Unchecking auto-submits and brings my puzzle back.
    uncheck "Hide my quartets"

    expect(page).to have_content(/mine to hide/i)
    expect(page).to have_field("Hide my quartets", checked: false)
  end

  it "shows no toggle to someone who owns nothing on the archive" do
    create(:published_puzzle, title: "Not mine")

    visit play_index_path

    expect(page).to have_content(/not mine/i)
    expect(page).to have_no_field("Hide my quartets")
  end
end
