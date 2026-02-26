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

ActiveRecord::Schema[8.1].define(version: 2026_02_26_214952) do
  create_table "achievements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "image_url"
    t.string "requirement_type"
    t.decimal "requirement_value"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_checksum", null: false
    t.string "message_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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

  create_table "assets_items", force: :cascade do |t|
    t.integer "assets_project_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "media_type"
    t.boolean "shipped"
    t.string "spritesheet_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["assets_project_id"], name: "index_assets_items_on_assets_project_id"
    t.index ["user_id"], name: "index_assets_items_on_user_id"
  end

  create_table "assets_projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "hackatime_ids"
    t.string "image_url"
    t.string "media_type"
    t.string "readme_url"
    t.string "repository_url"
    t.boolean "shipped"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_assets_projects_on_user_id"
  end

  create_table "audits", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.json "details", default: {}
    t.integer "project_id"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["action"], name: "index_audits_on_action"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["project_id"], name: "index_audits_on_project_id"
    t.index ["user_id"], name: "index_audits_on_user_id"
  end

  create_table "charm_notches", force: :cascade do |t|
    t.boolean "admin_granted", default: false, null: false
    t.integer "charm_slot_id"
    t.datetime "created_at", null: false
    t.integer "ship_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["charm_slot_id"], name: "index_charm_notches_on_charm_slot_id"
    t.index ["ship_id"], name: "index_charm_notches_on_ship_id"
    t.index ["user_id"], name: "index_charm_notches_on_user_id"
  end

  create_table "charm_slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "order_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["order_id"], name: "index_charm_slots_on_order_id"
    t.index ["user_id"], name: "index_charm_slots_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "devlog_id"
    t.datetime "last_editted"
    t.text "message"
    t.integer "ship_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["devlog_id"], name: "index_comments_on_devlog_id"
    t.index ["ship_id"], name: "index_comments_on_ship_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "devlogs", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.integer "duration_seconds"
    t.date "log_date"
    t.integer "project_id", null: false
    t.integer "ship_request_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["project_id", "created_at"], name: "index_devlogs_on_project_id_and_created_at"
    t.index ["project_id"], name: "index_devlogs_on_project_id"
    t.index ["ship_request_id"], name: "index_devlogs_on_ship_request_id"
    t.index ["user_id"], name: "index_devlogs_on_user_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "charm_image_url"
    t.float "cost"
    t.datetime "created_at", null: false
    t.integer "grant_amount_cents"
    t.float "price_usd"
    t.integer "product_id", null: false
    t.string "public_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["public_id"], name: "index_orders_on_public_id", unique: true
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id", "product_id"], name: "index_orders_on_user_product_pending_unique", unique: true, where: "status = 0"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "postable_id", null: false
    t.string "postable_type", null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["postable_type", "postable_id"], name: "index_posts_on_postable_type_and_postable_id", unique: true
    t.index ["project_id"], name: "index_posts_on_project_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "achievement_bool", default: false
    t.integer "achievement_id"
    t.float "cost_credits"
    t.datetime "created_at", null: false
    t.float "credits_per_dollar"
    t.string "description"
    t.integer "grant_amount_cents"
    t.boolean "grant_enabled", default: false, null: false
    t.integer "grant_max_cents"
    t.integer "grant_min_cents"
    t.string "image_url"
    t.boolean "limited", default: false, null: false
    t.string "link"
    t.string "name"
    t.integer "notch_cost"
    t.float "price_currency"
    t.boolean "show", default: true
    t.integer "steam_app_id"
    t.integer "steam_price_cents"
    t.integer "stock", default: 0
    t.datetime "updated_at", null: false
    t.boolean "variable_grant", default: false, null: false
    t.index ["achievement_id"], name: "index_products_on_achievement_id"
  end

  create_table "project_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "project_id"
    t.string "tag_string"
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_project_tags_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.integer "credits_per_hour"
    t.datetime "deleted_at"
    t.text "description"
    t.integer "devlogs_count", default: 0, null: false
    t.string "hackatime_id"
    t.text "hackatime_ids"
    t.string "name"
    t.integer "project_tag_id"
    t.string "readme_url"
    t.string "repository_url"
    t.datetime "ship_requested_at"
    t.boolean "shipped", default: false, null: false
    t.datetime "shipped_at"
    t.integer "ships_count", default: 0, null: false
    t.string "status"
    t.integer "total_seconds"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["deleted_at"], name: "index_projects_on_deleted_at"
    t.index ["user_id", "deleted_at"], name: "index_projects_on_user_id_and_deleted_at"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "ship_requests", force: :cascade do |t|
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.float "credits_awarded"
    t.float "credits_per_hour"
    t.integer "devlogged_seconds"
    t.integer "processed_by_id"
    t.integer "project_id", null: false
    t.datetime "requested_at"
    t.integer "ship_id"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["processed_by_id"], name: "index_ship_requests_on_processed_by_id"
    t.index ["project_id"], name: "index_ship_requests_on_project_id"
    t.index ["ship_id"], name: "index_ship_requests_on_ship_id"
    t.index ["user_id"], name: "index_ship_requests_on_user_id"
  end

  create_table "ships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "credits_awarded"
    t.integer "devlogged_seconds"
    t.text "hackatime_ids_snapshot"
    t.integer "project_id", null: false
    t.datetime "shipped_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["project_id", "shipped_at"], name: "index_ships_on_project_id_and_shipped_at"
    t.index ["project_id"], name: "index_ships_on_project_id"
    t.index ["user_id"], name: "index_ships_on_user_id"
  end

  create_table "site_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["key"], name: "index_site_settings_on_key", unique: true
  end

  create_table "spritesheets", force: :cascade do |t|
    t.integer "assets_item_id", null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["assets_item_id"], name: "index_spritesheets_on_assets_item_id"
  end

  create_table "user_achievements", force: :cascade do |t|
    t.integer "achievement_id", null: false
    t.datetime "created_at", null: false
    t.datetime "unlocked_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["achievement_id"], name: "index_user_achievements_on_achievement_id"
    t.index ["user_id", "achievement_id"], name: "index_user_achievements_on_user_id_and_achievement_id", unique: true
    t.index ["user_id"], name: "index_user_achievements_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.float "amount_spent", default: 0.0, null: false
    t.integer "charm_slots", default: 0, null: false
    t.datetime "created_at", null: false
    t.float "credit_offset", default: 0.0, null: false
    t.float "currency"
    t.string "email"
    t.boolean "flagged_for_fraud"
    t.integer "flagged_for_fraud_by_id"
    t.boolean "font_on", default: true, null: false
    t.string "hackatime_api_key"
    t.datetime "hackatime_synced_at"
    t.string "hackatime_trust_status"
    t.string "name"
    t.string "password_digest"
    t.string "provider"
    t.string "region"
    t.integer "role"
    t.string "slack_id"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.string "verification_status"
    t.index ["flagged_for_fraud_by_id"], name: "index_users_on_flagged_for_fraud_by_id"
    t.index ["hackatime_trust_status"], name: "index_users_on_hackatime_trust_status"
    t.index ["slack_id"], name: "index_users_on_slack_id"
    t.index ["uid"], name: "index_users_on_uid"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assets_items", "assets_projects"
  add_foreign_key "assets_items", "users"
  add_foreign_key "assets_projects", "users"
  add_foreign_key "audits", "projects"
  add_foreign_key "audits", "users"
  add_foreign_key "charm_notches", "charm_slots"
  add_foreign_key "charm_notches", "ships"
  add_foreign_key "charm_notches", "users"
  add_foreign_key "charm_slots", "orders"
  add_foreign_key "charm_slots", "users"
  add_foreign_key "comments", "devlogs"
  add_foreign_key "comments", "ships"
  add_foreign_key "comments", "users"
  add_foreign_key "devlogs", "projects"
  add_foreign_key "devlogs", "ship_requests"
  add_foreign_key "devlogs", "users"
  add_foreign_key "orders", "products"
  add_foreign_key "orders", "users"
  add_foreign_key "posts", "projects"
  add_foreign_key "posts", "users"
  add_foreign_key "products", "achievements"
  add_foreign_key "project_tags", "projects"
  add_foreign_key "projects", "users"
  add_foreign_key "ship_requests", "projects"
  add_foreign_key "ship_requests", "users"
  add_foreign_key "ship_requests", "users", column: "processed_by_id"
  add_foreign_key "ships", "projects"
  add_foreign_key "ships", "users"
  add_foreign_key "spritesheets", "assets_items"
  add_foreign_key "user_achievements", "achievements"
  add_foreign_key "user_achievements", "users"
  add_foreign_key "users", "users", column: "flagged_for_fraud_by_id"
end
