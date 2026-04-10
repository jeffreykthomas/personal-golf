class CreateLearningWorkspace < ActiveRecord::Migration[8.0]
  def change
    create_table :learning_nodes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :learning_nodes }
      t.string :title, null: false
      t.string :slug, null: false
      t.text :summary
      t.text :body_markdown
      t.integer :node_kind, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :learning_nodes, [:user_id, :slug], unique: true
    add_index :learning_nodes, [:user_id, :parent_id, :position]

    create_table :learning_sources do |t|
      t.references :learning_node, null: false, foreign_key: true
      t.integer :source_type, null: false, default: 0
      t.integer :extraction_status, null: false, default: 0
      t.string :title, null: false
      t.string :url
      t.integer :quality_score, null: false, default: 50
      t.string :publication_name
      t.string :author_name
      t.date :published_on
      t.text :summary_markdown
      t.text :extracted_content
      t.string :content_hash
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :learning_sources, [:learning_node_id, :url]
    add_index :learning_sources, [:learning_node_id, :source_type]

    create_table :learning_questions do |t|
      t.references :learning_node, null: false, foreign_key: true
      t.text :question_text, null: false
      t.text :answer_markdown
      t.integer :status, null: false, default: 0
      t.datetime :answered_at
      t.json :citations_data, null: false, default: []
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :learning_questions, [:learning_node_id, :created_at]

    create_table :learning_node_links do |t|
      t.references :from_node, null: false, foreign_key: { to_table: :learning_nodes }
      t.references :to_node, null: false, foreign_key: { to_table: :learning_nodes }
      t.integer :relation_kind, null: false, default: 0
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :learning_node_links, [:from_node_id, :to_node_id, :relation_kind], unique: true, name: "index_learning_node_links_unique"
  end
end
