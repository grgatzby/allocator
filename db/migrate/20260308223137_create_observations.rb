class CreateObservations < ActiveRecord::Migration[7.0]
  def change
    create_table :observations do |t|
      t.references :series, null: false, foreign_key: true
      t.date :period_date, null: false
      t.decimal :value, precision: 20, scale: 6, null: false
      t.string :status
      t.datetime :source_updated_at
      t.datetime :ingested_at, null: false
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :observations, [:series_id, :period_date], unique: true
    add_index :observations, :period_date
  end
end
