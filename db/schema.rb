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

ActiveRecord::Schema[8.1].define(version: 2026_02_08_190000) do
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

  create_table "devlogs", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "duration_minutes"
    t.date "log_date"
    t.integer "project_id"
    t.integer "ship_request_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["project_id"], name: "index_devlogs_on_project_id"
    t.index ["ship_request_id"], name: "index_devlogs_on_ship_request_id"
    t.index ["user_id"], name: "index_devlogs_on_user_id"
  end

  create_table "orders", force: :cascade do |t|
    t.float "cost"
    t.datetime "created_at", null: false
    t.integer "grant_amount_cents"
    t.float "price_usd"
    t.integer "product_id", null: false
    t.string "public_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["public_id"], name: "index_orders_on_public_id", unique: true
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id", "product_id"], name: "index_orders_on_user_product_pending_unique", unique: true, where: "status = 0"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.float "cost_credits"
    t.datetime "created_at", null: false
    t.float "credits_per_dollar"
    t.integer "grant_amount_cents"
    t.boolean "grant_enabled", default: false, null: false
    t.integer "grant_max_cents"
    t.integer "grant_min_cents"
    t.string "image_url"
    t.string "link"
    t.string "name"
    t.float "price_currency"
    t.integer "steam_app_id"
    t.integer "steam_price_cents"
    t.datetime "updated_at", null: false
    t.boolean "variable_grant", default: false, null: false
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.integer "credits_per_hour"
    t.datetime "deleted_at"
    t.text "description"
    t.boolean "featured", default: false, null: false
    t.datetime "featured_at", precision: nil
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
    t.integer "user_id"
    t.index ["deleted_at"], name: "index_projects_on_deleted_at"
    t.index ["featured"], name: "index_projects_on_featured"
    t.index ["featured_at"], name: "index_projects_on_featured_at"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "ship_requests", force: :cascade do |t|
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.float "credits_awarded"
    t.float "credits_per_hour"
    t.integer "devlogged_seconds"
    t.integer "processed_by_id"
    t.integer "project_id"
    t.datetime "requested_at"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["processed_by_id"], name: "index_ship_requests_on_processed_by_id"
    t.index ["project_id"], name: "index_ship_requests_on_project_id"
    t.index ["user_id"], name: "index_ship_requests_on_user_id"
  end

  create_table "ships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "credits_awarded"
    t.integer "devlogged_seconds"
    t.integer "project_id"
    t.datetime "shipped_at"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["project_id"], name: "index_ships_on_project_id"
    t.index ["user_id"], name: "index_ships_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "currency"
    t.string "email"
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
    t.index ["hackatime_trust_status"], name: "index_users_on_hackatime_trust_status"
    t.index ["uid"], name: "index_users_on_uid"
  end

  add_foreign_key "devlogs", "users"
  add_foreign_key "projects", "users"
  add_foreign_key "ship_requests", "projects"
  add_foreign_key "ship_requests", "users"
  add_foreign_key "ship_requests", "users", column: "processed_by_id"
  add_foreign_key "ships", "projects"
  add_foreign_key "ships", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
