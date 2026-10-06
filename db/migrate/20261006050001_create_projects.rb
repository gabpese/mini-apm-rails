class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :min_ram_mb
      t.string :min_os
      t.decimal :regression_ratio, precision: 4, scale: 2, null: false, default: 2
      t.integer :regression_min_sessions, null: false, default: 50

      t.timestamps
    end
  end
end
