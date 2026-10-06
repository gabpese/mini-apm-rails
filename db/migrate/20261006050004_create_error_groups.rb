class CreateErrorGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :error_groups do |t|
      t.references :project, null: false, foreign_key: true
      t.string :fingerprint, limit: 64, null: false
      t.text :message, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.bigint :occurrences, null: false, default: 0

      t.timestamps
    end

    add_index :error_groups, [ :project_id, :fingerprint ], unique: true
  end
end
