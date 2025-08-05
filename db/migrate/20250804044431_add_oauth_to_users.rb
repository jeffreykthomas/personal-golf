class AddOauthToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :google_token, :string
    add_column :users, :google_refresh_token, :string
    
    # Make password optional for OAuth users
    change_column_null :users, :password_digest, true
    
    # Add composite index for OAuth lookups
    add_index :users, [:provider, :uid], unique: true
  end
end
