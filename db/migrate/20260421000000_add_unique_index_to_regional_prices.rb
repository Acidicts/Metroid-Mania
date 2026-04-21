class AddUniqueIndexToRegionalPrices < ActiveRecord::Migration[7.0]
  def change
    add_index :regional_prices, [ :priceable_type, :priceable_id, :region ], unique: true, name: "index_regional_prices_on_priceable_and_region"
  end
end
