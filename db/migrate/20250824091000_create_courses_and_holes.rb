class CreateCoursesAndHoles < ActiveRecord::Migration[8.0]
  def change
    create_table :courses do |t|
      t.string :name, null: false
      t.string :location
      t.text :description
      t.timestamps
    end
    add_index :courses, :name, unique: true

    create_table :holes do |t|
      t.references :course, null: false, foreign_key: true
      t.integer :number, null: false
      t.integer :par
      t.integer :yardage
      t.timestamps
    end
    add_index :holes, [:course_id, :number], unique: true
  end
end


