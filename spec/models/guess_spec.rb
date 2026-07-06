require "rails_helper"

# The owner of the guess-log shape. One value object so the cube, stats, and
# trophies stop re-learning the jsonb layout (string keys from JSON, symbol keys
# in tests) and the "is this guess correct?" rule lives in exactly one place.
RSpec.describe Guess do
  describe "reading the shape" do
    it "reads string keys (the jsonb shape posted from the game)" do
      g = Guess.new("words" => %w[a b c d], "colors" => %w[blue blue blue blue])
      expect(g.words).to eq(%w[a b c d])
      expect(g.colors).to eq(%w[blue blue blue blue])
    end

    it "reads symbol keys (in-memory, as tests build them)" do
      g = Guess.new(words: %w[a b c d], colors: %i[blue green yellow purple])
      expect(g.words).to eq(%w[a b c d])
      expect(g.colors).to eq(%w[blue green yellow purple]) # coerced to strings
    end

    it "treats missing keys as empty rather than blowing up" do
      g = Guess.new({})
      expect(g.colors).to eq([])
      expect(g.words).to eq([])
    end
  end

  describe "#elapsed_ms — per-guess timing" do
    it "reads the ms-since-start the game records (string key)" do
      expect(Guess.new("colors" => %w[blue blue blue blue], "t" => 4200).elapsed_ms).to eq(4200)
    end

    it "coerces a stringy value to an integer" do
      expect(Guess.new(colors: %w[blue blue blue blue], t: "4200").elapsed_ms).to eq(4200)
    end

    it "is nil on plays recorded before timing shipped" do
      expect(Guess.new(colors: %w[blue blue blue blue]).elapsed_ms).to be_nil
    end
  end

  describe "correctness — derived from colors (the Connections rule)" do
    it "is correct when all four tiles share one color" do
      expect(Guess.new(colors: %w[purple purple purple purple])).to be_correct
    end

    it "is wrong when the tiles span groups" do
      g = Guess.new(colors: %w[blue blue green blue])
      expect(g).to be_wrong
      expect(g).not_to be_correct
    end

    it "is neither correct nor wrong when there are no colors" do
      g = Guess.new(colors: [])
      expect(g).not_to be_correct
      expect(g).not_to be_wrong
    end

    it "ignores any stored 'correct' flag — colors decide" do
      g = Guess.new("correct" => true, "colors" => %w[blue green blue green])
      expect(g).to be_wrong
    end
  end

  describe "#solved_color" do
    it "is the shared color of a correct guess" do
      expect(Guess.new(colors: %w[green green green green]).solved_color).to eq("green")
    end

    it "is nil for a wrong guess" do
      expect(Guess.new(colors: %w[blue green blue green]).solved_color).to be_nil
    end
  end
end
