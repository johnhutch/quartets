require "rails_helper"

# The editor's Publish button sits beside Save draft but stays greyed and
# un-submittable (with a tooltip) until the puzzle is complete.
RSpec.describe "Publishing from the editor", type: :system, js: true do
  let(:user) { create(:user) }
  before { login_as(user, scope: :user) }

  it "greys out Publish and blocks it while the draft is incomplete" do
    draft = create(:puzzle, user: user, title: "WIP", status: :unlisted)

    visit edit_puzzle_path(draft)

    expect(page).to have_css("button.is-disabled", text: /publish/i)
    find("button.is-disabled", text: /publish/i).click # guarded — does nothing
    expect(page).to have_current_path(edit_puzzle_path(draft))
    expect(draft.reload).to be_unlisted
  end

  it "lets a complete draft publish from the editor" do
    draft = create(:puzzle, :complete, user: user, status: :unlisted)

    visit edit_puzzle_path(draft)

    expect(page).to have_no_css("button.is-disabled")
    click_button "Publish"

    expect(page).to have_current_path(play_path(draft.share_token), ignore_query: true)
    expect(draft.reload).to be_published
  end
end
