# The resolved boolean becomes a typed resolution (fixed/willdo/wontdo/
# duplicate, NULL = still open) with an audit pair: when and by whom. Old
# dismissals carried no type — "wontdo" is closest in spirit (looked at it,
# not acting), stamped with the row's own updated_at.
class ReplaceReportResolvedWithResolution < ActiveRecord::Migration[8.1]
  def up
    add_column :reports, :resolution, :integer
    add_column :reports, :resolved_at, :datetime
    add_reference :reports, :resolved_by, foreign_key: { to_table: :users }

    execute "UPDATE reports SET resolution = 2, resolved_at = updated_at WHERE resolved"

    remove_column :reports, :resolved
    add_index :reports, :resolution
  end

  def down
    add_column :reports, :resolved, :boolean, default: false, null: false
    execute "UPDATE reports SET resolved = TRUE WHERE resolution IS NOT NULL"

    remove_index :reports, :resolution
    remove_reference :reports, :resolved_by
    remove_column :reports, :resolved_at
    remove_column :reports, :resolution
  end
end
