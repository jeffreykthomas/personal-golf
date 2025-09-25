class AddLayoutImageUrlToHoles < ActiveRecord::Migration[8.0]
  def change
    add_column :holes, :layout_image_url, :string
  end
end


