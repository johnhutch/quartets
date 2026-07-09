class TunePuzzleIndexes < ActiveRecord::Migration[8.1]
  def change
    # The archive/home/user pages all filter Puzzle.published and order by
    # created_at — back that with a composite index (matters once /play paginates
    # and the catalog grows).
    add_index :puzzles, [:status, :created_at]

    # No query ever filters on `specialized` (it's only read off already-loaded
    # records for the THEMED chip), so its index is dead write-cost. Drop it.
    remove_index :puzzles, :specialized
  end
end
