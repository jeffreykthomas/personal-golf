class AddHoleNumberToTips < ActiveRecord::Migration[8.0]
  def change
    add_column :tips, :hole_number, :integer
  end
end


