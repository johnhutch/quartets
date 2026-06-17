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

  it "wraps a long answer inside its tile instead of blowing the column out" do
    long = "supercalifragilisticexpialidocious"
    puzzle.groups.find_by(color: "blue").update!(words: ["cat", long, "dog", "owl"])
    visit play_path(puzzle.share_token)

    # minmax(0, 1fr) keeps every tile the same quarter-width; the long word wraps
    # (hyphenated) inside it rather than expanding its grid column.
    long_w  = find(".m-card", text: /#{long}/i).evaluate_script("this.clientWidth")
    short_w = find(".m-card", text: /\Acat\z/i).evaluate_script("this.clientWidth")
    expect(long_w).to be_within(2).of(short_w)
  end

  it "reveals every group and declares a win" do
    visit play_path(puzzle.share_token)

    answers.each_value { |group| solve(group) }

    expect(page).to have_content(/solved it/i) # the win stamp (uppercased by CSS)
    # The play controls retire once the game's over.
    expect(page).to have_no_button("Submit")
    expect(page).to have_no_button("Shuffle")
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

    expect(page).to have_content(/out of guesses/i) # the loss stamp
    expect(page).to have_no_button("Submit")
  end

  it "records the finished play for stats" do
    visit play_path(puzzle.share_token)

    answers.each_value { |group| solve(group) }

    # The engine flags the element once the background save round-trips.
    expect(page).to have_css(".m-game[data-recorded='true']")
    # …and shows the shareable cube it got back.
    expect(page).to have_css(".m-cube", text: "🟦")
    expect(page).to have_button("Copy result")

    attempt = Attempt.last
    expect(attempt.puzzle).to eq(puzzle)
    expect(attempt).to be_solved
  end

  it "awards a reverse rainbow for a flawless hardest-first win (ADR-0011)" do
    visit play_path(puzzle.share_token)

    # Purple → blue → green → yellow, no mistakes: the top trophy.
    %i[purple blue green yellow].each { |color| solve(answers[color]) }

    expect(page).to have_css(".m-trophy--reverse-rainbow")
    # Cumulative: a reverse rainbow is also a purple-first and a perfect.
    expect(page).to have_css(".m-awards__trophy", count: 3)
    expect(page).to have_css(".m-awards__quip")
    # Anonymous players are nudged to sign up rather than shown a farmable total.
    expect(page).to have_link("Sign up")
  end

  # Picks the four words then submits.
  it "clears every selection when Deselect all is clicked (cascade)" do
    visit play_path(puzzle.share_token)

    %w[cat dog owl].each { |word| click_button word }
    expect(page).to have_css(".m-card.is-selected", count: 3)

    click_button "Deselect all"

    # The tiles settle ~0.2s apart; Capybara waits out the stagger for the end state.
    expect(page).to have_no_css(".m-card.is-selected")
  end

  def solve(words)
    words.each { |word| click_button word }
    click_button "Submit"
  end
end
