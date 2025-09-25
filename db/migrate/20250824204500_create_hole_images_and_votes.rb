class CreateHoleImagesAndVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :hole_images do |t|
      t.references :hole, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false, default: 'original' # original | stylized
      t.string :status, null: false, default: 'ready'   # pending | processing | ready | failed
      t.integer :upvotes_count, null: false, default: 0
      t.integer :downvotes_count, null: false, default: 0
      t.integer :source_image_id
      t.text :error_message
      t.timestamps
    end
    add_index :hole_images, :source_image_id

    create_table :hole_image_votes do |t|
      t.references :hole_image, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :value, null: false # -1 or 1
      t.timestamps
    end
    add_index :hole_image_votes, [:hole_image_id, :user_id], unique: true
  end
end


