class AddCreatorTokenToPuzzles < ActiveRecord::Migration[8.1]
  def change
    add_column :puzzles, :creator_token, :string
    add_index :puzzles, :creator_token
  end
end
