class ChangeCoachJsonColumns < ActiveRecord::Migration[8.0]
  def up
    change_column :coach_sessions, :context_data, :json, default: {}, null: false
    change_column :coach_messages, :metadata, :json, default: {}, null: false
    change_column :coach_profiles, :profile_data, :json, default: {}, null: false
  end

  def down
    change_column :coach_sessions, :context_data, :text, default: "{}", null: false
    change_column :coach_messages, :metadata, :text, default: "{}", null: false
    change_column :coach_profiles, :profile_data, :text, default: "{}", null: false
  end
end
