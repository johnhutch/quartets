class AddAchievementToAttempts < ActiveRecord::Migration[8.1]
  def change
    # The trophy tier a flawless win earned (ADR-0011), nil = none. Ordered so the
    # cumulative counts ("perfect or better", etc.) are a cheap `achievement >= n`
    # query: 1 perfect, 2 purple_first, 3 reverse_rainbow.
    add_column :attempts, :achievement, :integer
    add_index :attempts, [:user_id, :achievement]
  end
end
