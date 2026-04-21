class AddEnabledToRegionalPrice < ActiveRecord::Migration[8.1]
  def change
    add_column :regional_prices, :enabled, :boolean
  end
end
