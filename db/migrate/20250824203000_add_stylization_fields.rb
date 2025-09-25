class AddStylizationFields < ActiveRecord::Migration[8.0]
  def change
    add_column :holes, :stylization_status, :string
    add_column :holes, :stylization_error, :text
    add_column :courses, :style_seed, :integer
  end
end


