class IndexAnonymousClaimLookups < ActiveRecord::Migration[8.1]
  # AnonymousClaim looks these two tables up by token alone, but the only indexes
  # covering those columns lead with puzzle_id, so both were sequential scans —
  # on every authentication, which includes every remembered re-auth. play_states
  # is the unbounded one (a row per drive-by visitor who makes a guess, pruned
  # only after a 30-day TTL), so this was a full scan on the first page load of
  # every returning session. attempts already had index_attempts_on_player_token,
  # which is what made the omission on the other two easy to miss.
  def change
    add_index :play_states, :player_token
    add_index :reports, :reporter_token
  end
end
