# Public per-account handle (the deferred D3 of ADR-0005): the /u/:handle page's
# stable slug. Generated from the email's local part; existing accounts are
# backfilled the same way new signups mint theirs (User#assign_handle).
class AddHandleToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :handle, :string
    add_index :users, :handle, unique: true

    # Backfill without depending on model code that may drift.
    taken = {}
    select_rows("SELECT id, email FROM users ORDER BY id").each do |id, email|
      base = email.to_s.split("@").first.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
      base = "player" if base.empty?
      candidate = base
      n = 1
      candidate = "#{base}-#{n += 1}" while taken[candidate]
      taken[candidate] = true
      update("UPDATE users SET handle = #{quote(candidate)} WHERE id = #{id.to_i}")
    end

    change_column_null :users, :handle, false
  end

  def down
    remove_column :users, :handle
  end
end
