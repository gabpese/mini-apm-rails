# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_06_050005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name"
    t.string "key_prefix", limit: 12, null: false
    t.string "key_hash", limit: 64, null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key_hash"], name: "index_api_keys_on_key_hash", unique: true
    t.index ["project_id"], name: "index_api_keys_on_project_id"
  end

  create_table "app_sessions", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "user_ref"
    t.string "app_version", limit: 32, null: false
    t.string "os"
    t.integer "ram_mb"
    t.string "gpu"
    t.datetime "started_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "app_version"], name: "index_app_sessions_on_project_id_and_app_version"
    t.index ["project_id", "started_at"], name: "index_app_sessions_on_project_id_and_started_at"
    t.index ["project_id", "user_ref", "app_version", "started_at"], name: "index_app_sessions_for_event_lookup"
    t.index ["project_id"], name: "index_app_sessions_on_project_id"
  end

  create_table "error_groups", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "fingerprint", limit: 64, null: false
    t.text "message", null: false
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.bigint "occurrences", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "fingerprint"], name: "index_error_groups_on_project_id_and_fingerprint", unique: true
    t.index ["project_id"], name: "index_error_groups_on_project_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "app_session_id"
    t.bigint "error_group_id"
    t.string "event_type", limit: 32, null: false
    t.string "name"
    t.string "app_version", limit: 32, null: false
    t.string "user_ref"
    t.datetime "occurred_at", null: false
    t.jsonb "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["app_session_id"], name: "index_events_on_app_session_id"
    t.index ["error_group_id"], name: "index_events_on_error_group_id"
    t.index ["project_id", "app_version", "event_type"], name: "index_events_on_project_id_and_app_version_and_event_type"
    t.index ["project_id", "event_type", "occurred_at"], name: "index_events_on_project_id_and_event_type_and_occurred_at"
    t.index ["project_id"], name: "index_events_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.integer "min_ram_mb"
    t.string "min_os"
    t.decimal "regression_ratio", precision: 4, scale: 2, default: "2.0", null: false
    t.integer "regression_min_sessions", default: 50, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.boolean "verified", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "api_keys", "projects"
  add_foreign_key "app_sessions", "projects"
  add_foreign_key "error_groups", "projects"
  add_foreign_key "events", "app_sessions", on_delete: :nullify
  add_foreign_key "events", "error_groups", on_delete: :nullify
  add_foreign_key "events", "projects"
  add_foreign_key "projects", "users"
  add_foreign_key "sessions", "users"
end
