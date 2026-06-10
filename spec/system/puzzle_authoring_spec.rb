require "rails_helper"

# End-to-end coverage of the authoring form in a real (headless, phone-sized)
# browser — the only place the auto-save Stimulus controller actually runs.
RSpec.describe "Authoring a puzzle on a phone", type: :system, js: true do
  let(:user) { create(:user) }
  before { login_as(user, scope: :user) }

  it "auto-saves a half-typed draft so leaving never loses work" do
    visit new_puzzle_path

    within(".m-group--blue") do
      fill_in "Word 1", with: "cat"
      fill_in "Word 2", with: "dog"
      fill_in "Category", with: "Animals"
    end

    # No button press — the debounced background save lands on its own.
    expect(page).to have_css('[data-autosave-target="status"]', text: "Saved")
    expect(Puzzle.count).to eq(1)

    # The iOS back button incarnate: leave without ever submitting, come back.
    visit edit_puzzle_path(Puzzle.last)

    within(".m-group--blue") do
      expect(page).to have_field("Word 1", with: "cat")
      expect(page).to have_field("Word 2", with: "dog")
      expect(page).to have_field("Category", with: "Animals")
    end
  end

  it "authors a full puzzle and publishes it" do
    visit new_puzzle_path

    fill_group "blue",   %w[cat dog owl fox], "Animals"
    fill_group "green",  %w[red blue teal jade], "Colors"
    fill_group "yellow", %w[one two three four], "Numbers"
    fill_group "purple", %w[mars venus pluto ceres], "Space"
    fill_in "Title", with: "Phone-authored"

    expect(page).to have_css('[data-autosave-target="status"]', text: "Saved")

    # The draft now exists; its editor is where Publish lives.
    visit edit_puzzle_path(Puzzle.last)
    click_button "Publish"

    expect(page).to have_current_path(puzzles_path)
    expect(Puzzle.last).to be_published
    # The dashboard title is display type, uppercased by the brutalist theme —
    # match the title, not its presentational casing.
    expect(page).to have_content(/phone-authored/i)
  end

  # Fills one color block: its four answers plus the category.
  def fill_group(color, words, category)
    within(".m-group--#{color}") do
      words.each_with_index { |word, i| fill_in "Word #{i + 1}", with: word }
      fill_in "Category", with: category
    end
  end
end
