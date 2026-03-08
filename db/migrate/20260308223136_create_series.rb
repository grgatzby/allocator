class CreateSeries < ActiveRecord::Migration[7.0]
  def change
    create_table :series do |t|
      t.references :data_source, null: false, foreign_key: true
      t.references :indicator, null: false, foreign_key: true
      t.references :country, null: true, foreign_key: true
      t.string :source_series_key, null: false
      t.string :frequency, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :series, [:data_source_id, :source_series_key], unique: true
    add_index :series, [:indicator_id, :country_id]
  end
end
