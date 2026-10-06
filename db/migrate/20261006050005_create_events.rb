class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :project, null: false, foreign_key: true
      t.references :app_session, foreign_key: { on_delete: :nullify }
      t.references :error_group, foreign_key: { on_delete: :nullify }
      t.string :event_type, limit: 32, null: false
      t.string :name
      t.string :app_version, limit: 32, null: false
      t.string :user_ref
      t.datetime :occurred_at, null: false
      t.jsonb :payload

      t.timestamps
    end

    add_index :events, [ :project_id, :event_type, :occurred_at ]
    add_index :events, [ :project_id, :app_version, :event_type ]
  end
end
