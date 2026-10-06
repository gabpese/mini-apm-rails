class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name
      t.string :key_prefix, limit: 12, null: false
      t.string :key_hash, limit: 64, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :api_keys, :key_hash, unique: true
  end
end
