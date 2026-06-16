require "rails_helper"

# Dashboard top-block stats (ADR-0011). Trophies + play stats come from the
# account's attempts; an anonymous author only gets a created count.
RSpec.describe PlayerStats do
  def flawless(user, order)
    create(:attempt, user: user, solved: true, mistakes_count: 0,
           guesses: order.map { |c| { "correct" => true, "words" => %w[a b c d], "colors" => [c] * 4 } })
  end

  describe "a signed-in player" do
    let(:user) { create(:user) }

    subject(:stats) { described_class.new(attempts: user.attempts, created: 3) }

    before do
      flawless(user, %w[purple blue green yellow]) # reverse rainbow (all three)
      flawless(user, %w[yellow green blue purple]) # perfect only
      create(:attempt, user: user, solved: true, mistakes_count: 2) # win, no trophy
      create(:attempt, user: user, solved: false, mistakes_count: 4) # loss
    end

    it "is signed in" do
      expect(stats).to be_signed_in
    end

    it "counts trophies cumulatively" do
      expect(stats.trophies).to eq(perfect: 2, purple_first: 1, reverse_rainbow: 1)
    end

    it "counts plays and solves" do
      expect(stats.played).to eq(4)
      expect(stats.solved).to eq(3)
    end

    it "computes a solve rate" do
      expect(stats.solve_rate).to be_within(0.001).of(0.75)
    end

    it "reports the created count it was handed" do
      expect(stats.created).to eq(3)
    end
  end

  describe "an anonymous author" do
    subject(:stats) { described_class.new(attempts: nil, created: 5) }

    it "is not signed in" do
      expect(stats).not_to be_signed_in
    end

    it "still reports created" do
      expect(stats.created).to eq(5)
    end
  end
end
