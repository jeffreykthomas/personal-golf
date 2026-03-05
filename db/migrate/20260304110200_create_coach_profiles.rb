class CreateCoachProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :coach_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :profile_data, null: false, default: "{}"
      t.text :summary
      t.integer :learned_facts_count, null: false, default: 0
      t.datetime :last_synced_at

      t.timestamps
    end
  end
end
