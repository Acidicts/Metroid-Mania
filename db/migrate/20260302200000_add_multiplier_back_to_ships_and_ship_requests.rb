class AddMultiplierBackToShipsAndShipRequests < ActiveRecord::Migration[8.1]
  def change
    # bring the multiplier columns back for historical tracking and future use
    add_column :ship_requests, :multiplier, :float, default: 1.0, null: false unless column_exists?(:ship_requests, :multiplier)
    add_column :ships, :multiplier, :float unless column_exists?(:ships, :multiplier)
  end
end
