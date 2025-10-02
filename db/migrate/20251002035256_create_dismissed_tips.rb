class CreateDismissedTips < ActiveRecord::Migration[8.0]
  def change
    create_table :dismissed_tips do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tip, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :dismissed_tips, [:user_id, :tip_id], unique: true
  end
end
