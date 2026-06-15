class AddUserToAttempts < ActiveRecord::Migration[8.1]
  def change
    add_reference :attempts, :user, null: true, foreign_key: true, index: false

    # One recorded play per logged-in user per puzzle (ADR-0009). Anonymous plays
    # (user_id NULL) are unconstrained — they keep the old replayable behavior.
    add_index :attempts, [:user_id, :puzzle_id],
              unique: true,
              where: "user_id IS NOT NULL",
              name: "index_attempts_on_user_and_puzzle"
  end
end
