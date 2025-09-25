class AddCourseToTips < ActiveRecord::Migration[8.0]
  def change
    add_reference :tips, :course, foreign_key: true
  end
end


