class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.string :path, null: false
      t.string :referrer          # the Referer header (previous URL), not personal
      t.string :user_agent
      t.boolean :bot, default: false, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :visits, :occurred_at
    add_index :visits, :bot
  end
end
