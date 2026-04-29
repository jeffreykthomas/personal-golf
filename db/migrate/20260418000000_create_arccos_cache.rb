class CreateArccosCache < ActiveRecord::Migration[8.0]
  def change
    create_table :arccos_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.float :handicap_index
      t.float :scoring_average
      t.integer :rounds_tracked
      t.json :smart_distances, null: false, default: {}
      t.json :aggregate_strokes_gained, null: false, default: {}
      t.json :metadata, null: false, default: {}
      t.datetime :last_synced_at
      t.string :last_sync_source_digest
      t.string :last_sync_status, null: false, default: "pending"
      t.text :last_sync_error

      t.timestamps
    end

    create_table :arccos_rounds do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id
      t.date :played_on, null: false
      t.string :course_name, null: false
      t.string :course_external_id
      t.integer :holes_played, null: false, default: 18
      t.integer :total_score
      t.integer :total_par
      t.integer :putts
      t.integer :greens_in_regulation
      t.integer :fairways_hit
      t.integer :fairways_attempted
      t.float :sg_total
      t.float :sg_putting
      t.float :sg_short_game
      t.float :sg_approach
      t.float :sg_off_tee
      t.json :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :arccos_rounds, [:user_id, :played_on]
    add_index :arccos_rounds, [:user_id, :course_name]
    add_index :arccos_rounds, [:user_id, :external_id], unique: true, where: "external_id IS NOT NULL"
  end
end
