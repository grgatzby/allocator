class CreateIndicators < ActiveRecord::Migration[7.0]
  def change
    create_table :indicators do |t|
      t.string :code
      t.string :name
      t.string :category
      t.string :unit
      t.string :default_frequency

      t.timestamps
    end
  end
end
