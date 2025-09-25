class AddUniqueIndexOnCoursesNameLocation < ActiveRecord::Migration[8.0]
  def up
    # Remove old simple name index if it exists to avoid duplicate constraints
    remove_index :courses, :name if index_exists?(:courses, :name)

    # Add case-insensitive unique index on name+location
    execute <<~SQL
      CREATE UNIQUE INDEX index_courses_on_lower_name_and_lower_location
      ON courses (LOWER(name), LOWER(location));
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_courses_on_lower_name_and_lower_location;
    SQL
    add_index :courses, :name, unique: true unless index_exists?(:courses, :name)
  end
end


