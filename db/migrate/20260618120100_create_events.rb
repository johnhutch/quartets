class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    # Lightweight play-funnel events (analytics stream B). The first writer is the
    # `game_started` beacon from game_controller — the only way to catch a started-
    # but-abandoned game, since nothing else hits the server between page load and
    # game over. Abandoned plays are *derived* later (a game_started with no
    # finishing Attempt, joined on player_token + puzzle, time-windowed) — nothing
    # extra to record. Keyed by the anonymous player_token like Attempt; user and
    # puzzle are optional so the model can carry non-play events later.
    create_table :events do |t|
      t.integer :event_type, null: false
      t.string :player_token, null: false
      t.references :user, foreign_key: true, null: true
      t.references :puzzle, foreign_key: true, null: true
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    # player_token feeds the future abandon join (started with no finishing
    # Attempt); occurred_at feeds the time-window + the >90d prune. event_type is
    # deliberately unindexed — it's a single low-cardinality value, so an index on
    # it just taxes writes without narrowing any query.
    add_index :events, :player_token
    add_index :events, :occurred_at
  end
end
