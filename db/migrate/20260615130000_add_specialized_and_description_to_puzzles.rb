class AddSpecializedAndDescriptionToPuzzles < ActiveRecord::Migration[8.1]
  def change
    # Discovery axis (grill 2026-06-15): off = "Classic" (the encouraged NYT-grade
    # general puzzle, the default); on = needs specialized/niche knowledge.
    add_column :puzzles, :specialized, :boolean, default: false, null: false
    add_index :puzzles, :specialized

    # Short, optional blurb — doubles as the og/twitter share description and the
    # future search field. Capped at 200 in the model (fits a Bluesky post + URL).
    add_column :puzzles, :description, :string
  end
end
