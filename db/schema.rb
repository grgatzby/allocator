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
    t.string "name", null: false
    t.string "iso2", null: false
    t.string "iso3", null: false
    t.string "region"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["iso2"], name: "index_countries_on_iso2", unique: true
    t.index ["iso3"], name: "index_countries_on_iso3", unique: true
  end

  create_table "data_sources", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "base_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_data_sources_on_code", unique: true
  end

  create_table "indicators", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "category", null: false
    t.string "unit"
    t.string "default_frequency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_indicators_on_category"
    t.index ["code"], name: "index_indicators_on_code", unique: true
  end

  create_table "ingestion_runs", force: :cascade do |t|
    t.bigint "data_source_id", null: false
    t.string "status", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.integer "rows_read", default: 0, null: false
    t.integer "rows_written", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id", "started_at"], name: "index_ingestion_runs_on_data_source_id_and_started_at"
    t.index ["data_source_id"], name: "index_ingestion_runs_on_data_source_id"
    t.index ["status"], name: "index_ingestion_runs_on_status"
  end

  create_table "observations", force: :cascade do |t|
    t.bigint "series_id", null: false
    t.date "period_date", null: false
    t.decimal "value", precision: 20, scale: 6, null: false
    t.string "status"
    t.datetime "source_updated_at"
    t.datetime "ingested_at", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["period_date"], name: "index_observations_on_period_date"
    t.index ["series_id", "period_date"], name: "index_observations_on_series_id_and_period_date", unique: true
    t.index ["series_id"], name: "index_observations_on_series_id"
  end

  create_table "series", force: :cascade do |t|
    t.bigint "data_source_id", null: false
    t.bigint "indicator_id", null: false
    t.bigint "country_id"
    t.string "source_series_key", null: false
    t.string "frequency", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_series_on_country_id"
    t.index ["data_source_id", "source_series_key"], name: "index_series_on_data_source_id_and_source_series_key", unique: true
    t.index ["data_source_id"], name: "index_series_on_data_source_id"
    t.index ["indicator_id", "country_id"], name: "index_series_on_indicator_id_and_country_id"
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
