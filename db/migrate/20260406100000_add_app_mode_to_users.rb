class AddAppModeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :app_mode, :integer, default: 0, null: false
    add_index :users, :app_mode
  end
end
