require "rails_helper"

# The archive's filter fold-out (signed-in only): "hide my puzzles" is on by
# default, "hide completed" off. Flipping a box auto-submits (GET — nothing is
# persisted).
RSpec.describe "Archive filters", type: :system, js: true do
  let(:user) { create(:user) }
  before { login_as(user, scope: :user) }

  it "reveals my own puzzles when hide-mine is unchecked" do
    create(:published_puzzle, user: user, title: "Self Portrait")
    create(:published_puzzle, title: "By A Stranger")

    visit play_index_path
    expect(page).to have_content(/by a stranger/i) # titles uppercase via CSS
    expect(page).to have_no_content(/self portrait/i) # filtered by default

    find(".m-filters__toggle").click
    uncheck "Hide my puzzles"

    expect(page).to have_content(/self portrait/i)
    # The fold-out stays open after the auto-submit, box still unchecked.
    expect(page).to have_unchecked_field("Hide my puzzles")
  end

  it "hides completed puzzles when asked" do
    played = create(:published_puzzle, title: "Old Conquest")
    create(:attempt, puzzle: played, user: user, solved: true)

    visit play_index_path
    expect(page).to have_content(/old conquest/i)

    find(".m-filters__toggle").click
    check "Hide completed puzzles"

    expect(page).to have_no_content(/old conquest/i)
  end
end
