class AddYoutubeUrlToTips < ActiveRecord::Migration[8.0]
  def change
    add_column :tips, :youtube_url, :string
    add_index :tips, :youtube_url
  end
end