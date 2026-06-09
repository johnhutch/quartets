class AddFeaturedToPuzzles < ActiveRecord::Migration[8.1]
  def change
    add_column :puzzles, :featured, :boolean, default: false, null: false
  end
end
