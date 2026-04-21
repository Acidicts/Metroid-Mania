class CreateRegionalPrices < ActiveRecord::Migration[8.1]
  def change
    create_table :regional_prices do |t|
      t.references :product, null: false, foreign_key: true
      t.string :region
      t.integer :cost

      t.timestamps
    end
  end
end
