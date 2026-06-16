require "rails_helper"

# The shareable artifact: a play's ordered guesses → the 🟨🟩🟦🟪 grid. Pure
# logic, so it gets tight coverage. Consumes Guesses (key/shape handling is the
# Guess value object's job — see guess_spec); these helpers wrap the raw rows.
RSpec.describe EmojiCube do
  def wrap(guesses) = Array(guesses).map { |raw| Guess.new(raw) }
  def cube(guesses) = described_class.new(wrap(guesses)).to_s

  it "maps each category color to its square" do
    guesses = [{ "colors" => %w[yellow green blue purple] }]
    expect(cube(guesses)).to eq("🟨🟩🟦🟪")
  end

  it "builds one row per guess, in order" do
    guesses = [
      { "colors" => %w[blue blue blue blue] },
      { "colors" => %w[green green green yellow] },
      { "colors" => %w[purple purple purple purple] }
    ]
    expect(cube(guesses)).to eq("🟦🟦🟦🟦\n🟩🟩🟩🟨\n🟪🟪🟪🟪")
  end

  it "preserves the pick order within a row" do
    guesses = [{ "colors" => %w[purple blue green yellow] }]
    expect(cube(guesses)).to eq("🟪🟦🟩🟨")
  end

  it "is empty when there were no guesses" do
    expect(cube([])).to eq("")
    expect(cube(nil)).to eq("")
  end

  it "accepts symbol keys and symbol colors too (not just jsonb strings)" do
    guesses = [{ colors: %i[blue green yellow purple] }]
    expect(cube(guesses)).to eq("🟦🟩🟨🟪")
  end

  it "falls back to a blank square for an unknown color rather than blowing up" do
    guesses = [{ "colors" => %w[blue chartreuse blue blue] }]
    expect(cube(guesses)).to eq("🟦⬜🟦🟦")
  end

  it "exposes rows as an array for rendering" do
    guesses = [{ "colors" => %w[blue blue blue blue] }, { "colors" => %w[green green green green] }]
    expect(described_class.new(wrap(guesses)).rows).to eq(["🟦🟦🟦🟦", "🟩🟩🟩🟩"])
  end
end
