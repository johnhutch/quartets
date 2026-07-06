class AddDurationMsToAttempts < ActiveRecord::Migration[8.1]
  def change
    # Total play time in milliseconds, measured client-side from first tile tap to
    # game over (nil for plays recorded before timing shipped, or if the clock
    # never started). Per-guess timing rides in the `guesses` jsonb (`t`); this is
    # the headline duration. Powers future speed stats — see TODOS "Stats".
    add_column :attempts, :duration_ms, :integer
  end
end
