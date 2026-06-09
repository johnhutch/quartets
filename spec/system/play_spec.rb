require "rails_helper"

# The game engine only truly runs in a browser, so this is where the loop gets
# proven: pick four → submit → reveal or mistake → win/lose. No login — play is
# public. (The :complete factory gives every group the same words, so we set
# distinct ones here, which is what a real puzzle has.)
RSpec.describe "Playing a puzzle", type: :system, js: true do
  let(:answers) do
    {
      blue:   %w[cat dog owl fox],
      green:  %w[one two three four],
      yellow: %w[mercury venus mars earth],
      purple: %w[piano drums bass flute]
    }
  end

  let(:puzzle) do
    create(:published_puzzle, title: "Playtime").tap do |p|
      p.groups.each do |group|
        group.update!(words: answers[group.color.to_sym], description: group.color.to_s.titleize)
      end
    end
  end

  it "renders all sixteen tiles" do
    visit play_path(puzzle.share_token)
    expect(page).to have_css(".m-card", count: 16)
  end

  it "reveals every group and declares a win" do
    visit play_path(puzzle.share_token)

    answers.each_value { |group| solve(group) }

    expect(page).to have_content("Solved it")
  end

  it "ends the game after four mistakes" do
    visit play_path(puzzle.share_token)

    # Four guesses that each deliberately straddle groups — all wrong.
    [
      %w[cat one mercury piano],
      %w[dog two venus drums],
      %w[owl three mars bass],
      %w[fox four earth flute]
    ].each { |guess| solve(guess) }

    expect(page).to have_content("Out of guesses")
  end

  # Picks the four words then submits.
  def solve(words)
    words.each { |word| click_button word }
    click_button "Submit"
  end
end
