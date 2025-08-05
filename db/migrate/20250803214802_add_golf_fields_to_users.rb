class AddGolfFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :name, :string
    add_column :users, :handicap, :integer
    add_column :users, :skill_level, :integer
    add_index :users, :skill_level
    add_column :users, :goals, :text
    add_column :users, :onboarding_completed, :boolean, default: false
  end
end
