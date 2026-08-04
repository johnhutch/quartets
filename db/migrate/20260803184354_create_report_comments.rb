# Staff triage notes on a report — an append-only thread, one row per comment,
# stamped with the staff author. Lives under /admin/puzzles/:id/reports.
class CreateReportComments < ActiveRecord::Migration[8.1]
  def change
    create_table :report_comments do |t|
      t.references :report, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end
  end
end
