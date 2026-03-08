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

ActiveRecord::Schema[7.0].define(version: 2026_03_08_223138) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "countries", force: :cascade do |t|
    t.string "name"
    t.string "iso2"
    t.string "iso3"
    t.string "region"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "data_sources", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.string "base_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "indicators", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.string "category"
    t.string "unit"
    t.string "default_frequency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ingestion_runs", force: :cascade do |t|
    t.bigint "data_source_id", null: false
    t.string "status"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "rows_read"
    t.integer "rows_written"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id"], name: "index_ingestion_runs_on_data_source_id"
  end

  create_table "observations", force: :cascade do |t|
    t.bigint "series_id", null: false
    t.date "period_date"
    t.decimal "value"
    t.string "status"
    t.datetime "source_updated_at"
    t.datetime "ingested_at"
    t.jsonb "raw_payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["series_id"], name: "index_observations_on_series_id"
  end

  create_table "series", force: :cascade do |t|
    t.bigint "data_source_id", null: false
    t.bigint "indicator_id", null: false
    t.bigint "country_id", null: false
    t.string "source_series_key"
    t.string "frequency"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_series_on_country_id"
    t.index ["data_source_id"], name: "index_series_on_data_source_id"
    t.index ["indicator_id"], name: "index_series_on_indicator_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "ingestion_runs", "data_sources"
  add_foreign_key "observations", "series"
  add_foreign_key "series", "countries"
  add_foreign_key "series", "data_sources"
  add_foreign_key "series", "indicators"
end
