class CreateCoachMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :coach_messages do |t|
      t.references :coach_session, null: false, foreign_key: true
      t.references :tip, foreign_key: true
      t.integer :role, null: false, default: 0
      t.integer :modality, null: false, default: 0
      t.text :content, null: false
      t.text :metadata, null: false, default: "{}"
      t.string :request_id

      t.timestamps
    end

    add_index :coach_messages, [:coach_session_id, :created_at], name: "idx_coach_messages_session_created_at"
    add_index :coach_messages, :request_id
  end
end
