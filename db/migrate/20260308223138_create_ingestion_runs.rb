class CreateIngestionRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :ingestion_runs do |t|
      t.references :data_source, null: false, foreign_key: true
      t.string :status, null: false # running, success, failed
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :rows_read, null: false, default: 0
      t.integer :rows_written, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    add_index :ingestion_runs, [:data_source_id, :started_at]
    add_index :ingestion_runs, :status
  end
end
