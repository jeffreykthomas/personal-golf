class CreateTips < ActiveRecord::Migration[8.0]
  def change
    create_table :tips do |t|
      t.string :title
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.integer :phase
      t.integer :skill_level
      t.integer :save_count, default: 0
      t.boolean :ai_generated, default: false
      t.boolean :published, default: false

      t.timestamps
    end
  end
end
