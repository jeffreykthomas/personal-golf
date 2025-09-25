class RemoveLayoutImageUrlFromHoles < ActiveRecord::Migration[8.0]
  def change
    remove_column :holes, :layout_image_url, :string
  end
end


