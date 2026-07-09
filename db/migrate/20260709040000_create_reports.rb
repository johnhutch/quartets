class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :puzzle, null: false, foreign_key: true
      # Who flagged it — account when signed in, else the anonymous player token.
      t.references :user, null: true, foreign_key: true
      t.string :reporter_token, null: false
      t.text :reason
      t.boolean :resolved, default: false, null: false
      t.timestamps
    end

    # One standing report per reporter per puzzle — a repeat flag is idempotent,
    # not a way to inflate the count.
    add_index :reports, [:puzzle_id, :reporter_token], unique: true
    add_index :reports, :resolved
  end
end
