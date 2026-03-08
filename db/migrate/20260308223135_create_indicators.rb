class CreateIndicators < ActiveRecord::Migration[7.0]
  def change
    create_table :indicators do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :category, null: false # gdp, rate, commodity
      t.string :unit
      t.string :default_frequency

      t.timestamps
    end

    add_index :indicators, :code, unique: true
    add_index :indicators, :category
  end
end
