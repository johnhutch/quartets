class CreateAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :attempts do |t|
      t.references :puzzle, null: false, foreign_key: true
      t.string :player_token
      t.boolean :solved
      t.integer :mistakes_count
      t.jsonb :guesses

      t.timestamps
    end
    add_index :attempts, :player_token
  end
end
