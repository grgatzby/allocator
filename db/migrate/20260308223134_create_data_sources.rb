class CreateDataSources < ActiveRecord::Migration[7.0]
  def change
    create_table :data_sources do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :base_url

      t.timestamps
    end

    add_index :data_sources, :code, unique: true
  end
end
