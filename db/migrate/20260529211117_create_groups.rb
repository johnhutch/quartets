class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups do |t|
      t.references :puzzle, null: false, foreign_key: true
      t.integer :color
      t.string :description
      t.jsonb :words
      t.integer :position

      t.timestamps
    end
  end
end
