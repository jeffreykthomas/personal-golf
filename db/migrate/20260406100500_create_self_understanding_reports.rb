class CreateSelfUnderstandingReports < ActiveRecord::Migration[8.0]
  def change
    create_table :self_understanding_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :framework_name, null: false, default: "Nine Currents"
      t.string :title, null: false, default: "Self-Understanding Report"
      t.text :body_markdown, null: false
      t.json :currents_data, null: false, default: {}
      t.json :source_snapshot, null: false, default: {}
      t.string :source_digest, null: false
      t.datetime :source_updated_at
      t.datetime :generated_at, null: false

      t.timestamps
    end

    add_index :self_understanding_reports, [:user_id, :generated_at]
    add_index :self_understanding_reports, [:user_id, :source_digest]
  end
end
