class CreateCoachSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :coach_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :phase, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :title
      t.text :context_data, null: false, default: "{}"
      t.string :external_session_id
      t.datetime :started_at
      t.datetime :ended_at
      t.datetime :last_activity_at

      t.timestamps
    end

    add_index :coach_sessions, [:user_id, :status, :phase], name: "idx_coach_sessions_user_status_phase"
    add_index :coach_sessions, :external_session_id
  end
end
