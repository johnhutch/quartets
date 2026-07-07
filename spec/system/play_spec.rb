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

  it "keeps the remaining tiles the same height after a group is solved" do
    visit play_path(puzzle.share_token)

    before_h = find(".m-card", text: /\Acat\z/i).evaluate_script("this.offsetHeight")
    solve(answers[:green])
    expect(page).to have_css(".m-card", count: 12)

    # The board's CLS min-height reservation must shrink with the grid — otherwise
    # the leftover space stretches the remaining rows and the tiles grow.
    after_h = find(".m-card", text: /\Acat\z/i).evaluate_script("this.offsetHeight")
    expect(after_h).to be_within(2).of(before_h)
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

    # Four guesses that each deliberately straddle groups — all wrong. A wrong
    # guess stays selected now, so each retry starts by clearing the last one.
    [
      %w[cat one mercury piano],
      %w[dog two venus drums],
      %w[owl three mars bass],
      %w[fox four earth flute]
    ].each_with_index do |guess, i|
      click_button "Deselect all" if i.positive?
      solve(guess)
    end

    expect(page).to have_content(/out of guesses/i) # the loss stamp
    expect(page).to have_no_button("Submit")
  end

  it "keeps a wrong guess highlighted until the player clears it" do
    visit play_path(puzzle.share_token)

    solve(%w[cat one mercury piano]) # deliberately wrong

    # The four picks stay lifted — unpick them yourself, or Deselect all.
    expect(page).to have_css(".m-card.is-selected", count: 4)
    expect(page).to have_css(".m-mistake.is-used", count: 1)

    # Resubmitting the identical four tells them instead of burning a mistake.
    click_button "Submit"
    expect(page).to have_content(/already made that guess/i)
    expect(page).to have_css(".m-mistake.is-used", count: 1)

    click_button "Deselect all"
    expect(page).to have_no_css(".m-card.is-selected")
  end

  it "rates the puzzle from the game-over screen" do
    visit play_path(puzzle.share_token)

    answers.each_value { |group| solve(group) }

    # The rating block rides in with the finished-play response.
    expect(page).to have_content(/was this a good one\?/i)
    click_button "Hell yeah!"
    expect(page).to have_css(".m-rating__opt.is-on", text: /hell yeah/i)

    click_button "@!#?@!"
    expect(page).to have_css(".m-rating__opt.is-on", count: 2)

    attempt = Attempt.last
    expect(attempt.quality).to eq("hell_yeah")
    expect(attempt.difficulty).to eq("cursed")
  end

  it "records the finished play for stats" do
    visit play_path(puzzle.share_token)

    answers.each_value { |group| solve(group) }

    # The engine flags the element once the background save round-trips.
    expect(page).to have_css(".m-game[data-recorded='true']")
    # …and shows the shareable cube it got back, as palette-matched blocks.
    expect(page).to have_css(".m-cube .m-cube__cell--blue", count: 4)
    expect(page).to have_button("Copy result")

    attempt = Attempt.last
    expect(attempt.puzzle).to eq(puzzle)
    expect(attempt).to be_solved
  end

  it "beacons game_started on the first tap and records play timing" do
    visit play_path(puzzle.share_token)

    # No event until the player actually starts.
    click_button "cat" # first tile tap fires the game_started beacon
    expect(page).to have_css(".m-game[data-started='true']")
    expect(Event.where(puzzle: puzzle).game_started.count).to eq(1)

    # Finish out the win and let the record round-trip land.
    click_button "dog"
    click_button "owl"
    click_button "fox"
    click_button "Submit"
    answers.except(:blue).each_value { |group| solve(group) }
    expect(page).to have_css(".m-game[data-recorded='true']")

    attempt = Attempt.last
    expect(attempt.duration_ms).to be_present
    expect(attempt.guesses.first["t"]).to be_present
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
