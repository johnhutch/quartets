require "rails_helper"

# The creatable tag combobox only runs in a real browser (Stimulus + the
# /tags autocomplete fetch). Reveal on "specialized", suggest existing, create new.
RSpec.describe "Tag combobox", type: :system, js: true do
  let(:user) { create(:user) }
  before { login_as(user, scope: :user) }

  it "stays hidden until 'specialized' is checked, then creates + saves a new tag" do
    puzzle = create(:puzzle, :complete, user: user, title: "Galaxy")
    visit edit_puzzle_path(puzzle)

    # The tag panel is collapsed by default (Classic).
    expect(page).to have_selector("#tag-input", visible: :hidden)

    check "YES"
    expect(page).to have_selector("#tag-input", visible: :visible)

    fill_in "tag-input", with: "Star Wars"
    # No existing tags → the menu offers a create affordance, labeled as such.
    # (Regex: the brutal theme renders chips/options uppercase via CSS.)
    expect(page).to have_css(".m-tags__option", text: /create new tag: star-wars/i)

    find("#tag-input").send_keys(:enter)
    expect(page).to have_css(".m-tags__chip", text: /star-wars/i)

    click_button "Keep it unlisted (link only)"
    expect(page).to have_current_path(puzzles_path)

    expect(puzzle.reload).to be_specialized
    expect(puzzle.tag_names).to include("star-wars")
  end

  it "autosaves a tag the instant it's added — no manual save needed" do
    puzzle = create(:puzzle, :complete, user: user, title: "Galaxy")
    visit edit_puzzle_path(puzzle)

    check "YES"
    fill_in "tag-input", with: "Star Wars"
    find("#tag-input").send_keys(:enter)
    expect(page).to have_css(".m-tags__chip", text: /star-wars/i)

    # No submit click — adding the chip must trigger the background autosave so
    # the tag survives an iOS-back-button navigation.
    expect(page).to have_css('[data-autosave-target="status"]', text: /saved/i)
    expect(puzzle.reload.tag_names).to include("star-wars")
  end

  it "suggests an existing tag instead of creating a duplicate" do
    Tag.create!(name: "star-wars")
    puzzle = create(:puzzle, :complete, user: user)
    visit edit_puzzle_path(puzzle)

    check "YES"
    fill_in "tag-input", with: "star"

    within(".m-tags__menu") do
      expect(page).to have_css(".m-tags__option", text: /\Astar-wars\z/i)
    end
  end
end
