# Superuser role (gates /admin) + Devise trackable columns (the admin users tab
# shows last-login times; trackable is what records them).
class AddSuperuserAndTrackableToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :superuser, :boolean, default: false, null: false

    add_column :users, :sign_in_count, :integer, default: 0, null: false
    add_column :users, :current_sign_in_at, :datetime
    add_column :users, :last_sign_in_at, :datetime
    add_column :users, :current_sign_in_ip, :string
    add_column :users, :last_sign_in_ip, :string
  end
end
