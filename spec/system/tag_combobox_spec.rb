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

  it "collapses the tag box when you un-specialize with no tags (no confirm needed)" do
    puzzle = create(:puzzle, :complete, user: user)
    visit edit_puzzle_path(puzzle)
    check "YES"
    expect(page).to have_selector("#tag-input", visible: :visible)
    find("#puzzle_specialized").click # uncheck — no tags, no confirm
    expect(page).to have_selector("#tag-input", visible: :hidden)
  end

  it "confirms before clearing tags when you turn specialized off, then removes them on accept" do
    puzzle = create(:puzzle, :complete, user: user)
    puzzle.update!(specialized: true, tag_names: ["star-wars"])
    visit edit_puzzle_path(puzzle)
    expect(page).to have_css(".m-tags__chip", text: /star-wars/i)

    accept_confirm("Remove all tags from this quartet?") do
      find("#puzzle_specialized").click
    end

    expect(page).to have_no_css(".m-tags__chip")
    expect(page).to have_selector("#tag-input", visible: :hidden) # the box slid closed
    expect(page).to have_css('[data-autosave-target="status"]', text: /saved/i)
    expect(puzzle.reload.tag_names).to eq([])
    expect(puzzle.reload).not_to be_specialized
  end

  it "keeps the tags (and stays specialized) when you decline" do
    puzzle = create(:puzzle, :complete, user: user)
    puzzle.update!(specialized: true, tag_names: ["star-wars"])
    visit edit_puzzle_path(puzzle)

    dismiss_confirm("Remove all tags from this quartet?") do
      find("#puzzle_specialized").click
    end

    expect(page).to have_css(".m-tags__chip", text: /star-wars/i)
    expect(puzzle.reload).to be_specialized
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
