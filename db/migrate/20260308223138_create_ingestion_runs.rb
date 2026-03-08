class CreateIngestionRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :ingestion_runs do |t|
      t.references :data_source, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :rows_read
      t.integer :rows_written
      t.text :error_message

      t.timestamps
    end
  end
end
