class AddDeletedAtToPuzzles < ActiveRecord::Migration[8.1]
  def change
    add_column :puzzles, :deleted_at, :datetime
    add_index :puzzles, :deleted_at
  end
end
