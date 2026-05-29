class CreatePuzzles < ActiveRecord::Migration[8.1]
  def change
    create_table :puzzles do |t|
      t.string :title
      t.string :author_name
      t.integer :status
      t.string :share_token
      t.integer :user_id

      t.timestamps
    end
    add_index :puzzles, :share_token, unique: true
    add_index :puzzles, :user_id
  end
end
