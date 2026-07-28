class AddPublishedAtToPuzzles < ActiveRecord::Migration[8.1]
  def up
    # When a puzzle went public. Status changes weren't timestamped, so lists
    # could only ever sort by created_at/updated_at — neither of which is when
    # the thing actually shipped. Set on publish, cleared on unpublish
    # (Puzzle#stamp_published_at).
    add_column :puzzles, :published_at, :datetime

    # Backfill: created_at is the honest choice for rows that predate the column
    # — it's a lower bound that never moves, and it preserves the order the
    # archive was already showing (it sorted by created_at). updated_at would
    # date a puzzle by its last edit, which is a different thing entirely.
    execute <<~SQL
      UPDATE puzzles SET published_at = created_at WHERE status = 1
    SQL
  end

  def down
    remove_column :puzzles, :published_at
  end
end
