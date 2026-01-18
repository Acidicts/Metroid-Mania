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

ActiveRecord::Schema[8.1].define(version: 2026_01_18_090000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", precision: nil, null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name"
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "audits", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.json "details", default: {}
    t.integer "project_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["action"], name: "index_audits_on_action"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["project_id"], name: "index_audits_on_project_id"
    t.index ["user_id"], name: "index_audits_on_user_id"
  end

  create_table "devlogs", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.date "log_date"
    t.integer "project_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_devlogs_on_project_id"
  end

  create_table "orders", force: :cascade do |t|
    t.float "cost"
    t.datetime "created_at", null: false
    t.integer "product_id", null: false
    t.string "public_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["public_id"], name: "index_orders_on_public_id", unique: true
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id", "product_id", "status"], name: "index_orders_on_user_product_status", unique: true
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.float "price_currency"
    t.integer "steam_app_id"
    t.integer "steam_price_cents"
    t.datetime "updated_at", null: false
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.integer "credits_per_hour"
    t.text "description"
    t.string "hackatime_id"
    t.text "hackatime_ids"
    t.string "name"
    t.string "readme_url"
    t.string "repository_url"
    t.datetime "ship_requested_at"
    t.boolean "shipped", default: false, null: false
    t.datetime "shipped_at"
    t.string "status"
    t.integer "total_seconds"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "ships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "credits_awarded"
    t.integer "devlogged_seconds"
    t.integer "project_id", null: false
    t.datetime "shipped_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["project_id"], name: "index_ships_on_project_id"
    t.index ["user_id"], name: "index_ships_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "currency"
    t.string "email"
    t.string "hackatime_api_key"
    t.string "name"
    t.string "password_digest"
    t.string "provider"
    t.integer "role"
    t.string "slack_id"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.string "verification_status"
    t.index ["uid"], name: "index_users_on_uid"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audits", "projects"
  add_foreign_key "audits", "users"
  add_foreign_key "devlogs", "projects"
  add_foreign_key "orders", "products"
  add_foreign_key "orders", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "ships", "projects"
  add_foreign_key "ships", "users"
end
