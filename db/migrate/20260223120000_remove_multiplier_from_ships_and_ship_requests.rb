class RemoveMultiplierFromShipsAndShipRequests < ActiveRecord::Migration[8.1]
  def change
    remove_column :ships, :multiplier, :float
    remove_column :ship_requests, :multiplier, :float
  end
end
