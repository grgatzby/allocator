class CreateSeries < ActiveRecord::Migration[7.0]
  def change
    create_table :series do |t|
      t.references :data_source, null: false, foreign_key: true
      t.references :indicator, null: false, foreign_key: true
      t.references :country, null: false, foreign_key: true
      t.string :source_series_key
      t.string :frequency
      t.jsonb :metadata

      t.timestamps
    end
  end
end
