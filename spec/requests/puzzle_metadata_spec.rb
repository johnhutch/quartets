require "rails_helper"

# Discovery metadata round-trips through the puzzle form (ADR-pending grill
# 2026-06-15): a short description, the specialized flag, and normalized tags.
RSpec.describe "Puzzle discovery metadata", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  it "saves description, the specialized flag, and normalized/deduped tags" do
    puzzle = create(:puzzle, user: user)

    patch puzzle_path(puzzle), params: { puzzle: {
      description: "A Star Wars quartet — ships, planets, quotes.",
      specialized: "1",
      tag_names: ["Star Wars", "star wars", "  ", "Bluey"]
    } }

    puzzle.reload
    expect(puzzle.description).to eq("A Star Wars quartet — ships, planets, quotes.")
    expect(puzzle).to be_specialized
    expect(puzzle.tag_names).to contain_exactly("star-wars", "bluey")
  end

  it "clears tags when only the blank placeholder comes back" do
    puzzle = create(:puzzle, user: user)
    puzzle.update!(tag_names: ["Star Wars"])

    patch puzzle_path(puzzle), params: { puzzle: { tag_names: [""] } }

    expect(puzzle.reload.tag_names).to eq([])
  end

  it "defaults to Classic (not specialized) and no description" do
    puzzle = create(:puzzle, user: user)
    expect(puzzle).not_to be_specialized
    expect(puzzle.description).to be_nil
  end
end
