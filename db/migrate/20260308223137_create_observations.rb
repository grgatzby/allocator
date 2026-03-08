class CreateObservations < ActiveRecord::Migration[7.0]
  def change
    create_table :observations do |t|
      t.references :series, null: false, foreign_key: true
      t.date :period_date
      t.decimal :value
      t.string :status
      t.datetime :source_updated_at
      t.datetime :ingested_at
      t.jsonb :raw_payload

      t.timestamps
    end
  end
end
