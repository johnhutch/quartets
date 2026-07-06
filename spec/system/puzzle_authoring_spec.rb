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
    expect(page).to have_css('[data-autosave-target="status"]', text: /saved/i)
    expect(Puzzle.count).to eq(1)

    # The iOS back button incarnate: leave without ever submitting, come back.
    visit edit_puzzle_path(Puzzle.last)

    within(".m-group--blue") do
      expect(page).to have_field("Word 1", with: "cat")
      expect(page).to have_field("Word 2", with: "dog")
      expect(page).to have_field("Category", with: "Animals")
    end
  end

  it "auto-saves continuously across the POST-to-PATCH boundary without ID collisions" do
    visit new_puzzle_path

    # Step 1: Type the first word. This triggers the initial POST autosave.
    within(".m-group--blue") do
      fill_in "Word 1", with: "first"
    end

    # Wait for the first save to finish and mint the draft
    expect(page).to have_css('[data-autosave-target="status"]', text: /saved/i)
    expect(Puzzle.count).to eq(1)

    # Step 2: Keep typing. The form has now switched to PATCH mode.
    within(".m-group--blue") do
      fill_in "Word 2", with: "second"
    end

    # If the ID mismatch bug is present, the PATCH will hit the uniqueness
    # validation, fail with a 422, and the UI will say "Save failed".
    # Capybara will time out here waiting for it to return to "Saved".
    expect(page).to have_css('[data-autosave-target="status"]', text: /saved/i)

    # Final sanity check: ensure the database actually received the second word
    # and didn't accidentally duplicate the groups.
    puzzle = Puzzle.last
    expect(puzzle.groups.find_by(color: "blue").words).to include("second")
    expect(puzzle.groups.count).to eq(4)
  end
  it "authors a full puzzle, publishes it, and lands on its shareable board" do
    visit new_puzzle_path

    fill_group "blue",   %w[cat dog owl fox], "Animals"
    fill_group "green",  %w[red blue teal jade], "Colors"
    fill_group "yellow", %w[one two three four], "Numbers"
    fill_group "purple", %w[mars venus pluto ceres], "Space"
    fill_in "Title", with: "Phone-authored"

    expect(page).to have_css('[data-autosave-target="status"]', text: /saved/i)
    # Now that every field is filled, the save button promotes itself to the
    # "keep it unlisted" choice, and Publish reveals + lights up right here on the
    # create screen — no reload, no trip to the editor (ADR-0008).
    expect(page).to have_button("Keep it unlisted (link only)")
    expect(page).to have_button("Publish")

    click_button "Publish"

    # Publishing drops the author straight onto the live, playable board with a
    # celebratory "it's published!" banner + a Share button. The full
    # author→publish→play loop.
    share_token = Puzzle.last.share_token
    expect(page).to have_current_path(play_path(share_token), ignore_query: true)
    expect(Puzzle.last).to be_published
    expect(page).to have_content(/phone-authored.*is published!/i)
    expect(page).to have_content(/share it with your friends and enemies/i)
    expect(page).to have_css(".m-publish-prompt--done button[data-action='share#share']")
    # The author sees their own board revealed, not playable — owners don't play
    # their own puzzles (no self-earned trophies or stats).
    expect(page).to have_css(".m-game__group", count: 4)
    expect(page).to have_no_css("[data-controller='game']")
  end

  # Fills one color block: its four answers plus the category.
  def fill_group(color, words, category)
    within(".m-group--#{color}") do
      words.each_with_index { |word, i| fill_in "Word #{i + 1}", with: word }
      fill_in "Category", with: category
    end
  end
end
