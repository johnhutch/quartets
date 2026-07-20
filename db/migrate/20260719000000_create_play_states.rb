class CreatePlayStates < ActiveRecord::Migration[8.1]
  def change
    create_table :play_states do |t|
      t.references :puzzle, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :player_token, null: false
      t.jsonb :guesses, null: false, default: []
      t.integer :elapsed_ms

      t.timestamps
    end

    # One saved game per player per puzzle — accounts and anonymous tokens each
    # get their own uniqueness lane (mirrors the attempts one-play index).
    add_index :play_states, %i[puzzle_id user_id], unique: true,
              where: "user_id IS NOT NULL", name: "index_play_states_on_puzzle_and_user"
    add_index :play_states, %i[puzzle_id player_token], unique: true,
              where: "user_id IS NULL", name: "index_play_states_on_puzzle_and_player"
  end
end
