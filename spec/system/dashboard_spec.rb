require "rails_helper"

# Owner dashboard interactions that only really run in a browser.
RSpec.describe "Your puzzles dashboard", type: :system, js: true do
  let(:user) { create(:user) }
  before { login_as(user, scope: :user) }

  # The Share buttons go through the native share sheet when the device has one
  # (iOS/Android) — a URL composed by the sheet unfurls into a rich link in
  # Messages, where a pasted one often doesn't. Desktop keeps the clipboard copy.
  it "shares a published puzzle's link through the native share sheet when available" do
    puzzle = create(:published_puzzle, user: user, title: "Pass It On")

    visit puzzles_path
    page.execute_script(<<~JS)
      navigator.share = (data) => { window.__shared = data; return Promise.resolve() }
      navigator.canShare = () => true
    JS
    click_button "Share"

    shared_url = page.evaluate_script("window.__shared && window.__shared.url")
    expect(shared_url).to end_with(play_path(puzzle.share_token)) # host is Capybara's
    expect(page).to have_no_content(/copied!/i) # the sheet took it; no copy fallback
  end

  it "falls back to copying the link when there is no native share sheet" do
    create(:published_puzzle, user: user, title: "Old School")

    visit puzzles_path
    # Force a share-sheet-less browser (Chrome on macOS defines navigator.share
    # even headless). writeText is stubbed too: the real one needs a clipboard
    # permission the test browser doesn't grant.
    page.execute_script(<<~JS)
      navigator.share = undefined
      Object.defineProperty(navigator, "clipboard", { value: { writeText: () => Promise.resolve() } })
    JS
    click_button "Share"

    expect(page).to have_content(/copied!/i) # button chrome uppercases via CSS
  end

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
