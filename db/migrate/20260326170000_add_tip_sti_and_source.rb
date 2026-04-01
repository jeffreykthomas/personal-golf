class AddTipStiAndSource < ActiveRecord::Migration[8.0]
  class MigrationTip < ApplicationRecord
    self.table_name = "tips"
  end

  def up
    add_column :tips, :type, :string
    add_column :tips, :source, :integer, default: 0, null: false
    change_column_null :tips, :category_id, true

    add_index :tips, :type
    add_index :tips, :source

    MigrationTip.where(type: nil).update_all(type: "GolfTip")
  end

  def down
    remove_index :tips, :source
    remove_index :tips, :type

    change_column_null :tips, :category_id, false
    remove_column :tips, :source
    remove_column :tips, :type
  end
end
