class CreateHoleTees < ActiveRecord::Migration[8.0]
  def change
    create_table :hole_tees do |t|
      t.references :hole, null: false, foreign_key: true
      t.string :name, null: false # e.g., Blue, White, Red
      t.string :color # hex or name, optional
      t.integer :yardage, null: false
      t.timestamps
    end
    add_index :hole_tees, [:hole_id, :name], unique: true
  end
end


