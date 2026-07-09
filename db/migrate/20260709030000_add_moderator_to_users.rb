class AddModeratorToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :moderator, :boolean, default: false, null: false
  end
end
