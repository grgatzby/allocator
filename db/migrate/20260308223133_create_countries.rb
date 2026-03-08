class CreateCountries < ActiveRecord::Migration[7.0]
  def change
    create_table :countries do |t|
      t.string :name, null: false
      t.string :iso2, null: false
      t.string :iso3, null: false
      t.string :region

      t.timestamps
    end

    add_index :countries, :iso2, unique: true
    add_index :countries, :iso3, unique: true
  end
end
