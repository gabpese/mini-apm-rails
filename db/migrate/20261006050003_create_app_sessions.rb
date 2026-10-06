class CreateAppSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :app_sessions do |t|
      t.references :project, null: false, foreign_key: true
      t.string :user_ref
      t.string :app_version, limit: 32, null: false
      t.string :os
      t.integer :ram_mb
      t.string :gpu
      t.datetime :started_at, null: false

      t.timestamps
    end

    add_index :app_sessions, [ :project_id, :app_version ]
    add_index :app_sessions, [ :project_id, :started_at ]
    add_index :app_sessions, [ :project_id, :user_ref, :app_version, :started_at ], name: "index_app_sessions_for_event_lookup"
  end
end
