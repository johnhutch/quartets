class AddSourceToVisits < ActiveRecord::Migration[8.1]
  def change
    # Referrer classified at write time (direct/ai/search/social/other), so the
    # dashboard groups in SQL instead of re-classifying every row on read.
    add_column :visits, :source, :string, null: false, default: "direct"
    add_index :visits, :source
  end
end
