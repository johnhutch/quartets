require "rails_helper"

# The topbar collapses to a CSS-only <details> hamburger on phones (the system
# suite runs at a 390px viewport). No JS of our own — just native <details> —
# but it only truly hides/reveals in a real browser, so this is a system spec.
# The homepage fronts its own nav (no topbar), so these exercise the archive page.
RSpec.describe "Mobile navigation", type: :system, js: true do
  it "keeps the nav behind a hamburger until tapped, with Create inside" do
    visit play_index_path

    expect(page).to have_css("summary.l-nav__toggle") # the hamburger button

    within(".l-nav") do
      expect(page).to have_no_link("Play More")       # collapsed: items hidden
      find("summary.l-nav__toggle").click             # open the sheet
      expect(page).to have_link("Create")             # the tilted-yellow item
      expect(page).to have_link("Play More")
      expect(page).to have_link("Sign up")            # logged-out auth row
    end
  end

  it "opens the create form straight from the hamburger" do
    visit play_index_path
    find("summary.l-nav__toggle").click
    within(".l-nav") { click_link "Create" }

    expect(page).to have_current_path(new_puzzle_path)
  end

  it "drops the hamburger's Create link while you're on the authoring page" do
    visit new_puzzle_path
    find("summary.l-nav__toggle").click

    within(".l-nav") do
      expect(page).to have_no_link("Create")  # you're already creating
      expect(page).to have_link("Play More")  # the rest of the menu stays
    end
  end

  it "hides the page's redundant Create sticker on mobile (the hamburger has it)" do
    visit play_index_path

    expect(page).to have_no_css(".m-create-sticker", visible: true)
  end
end
