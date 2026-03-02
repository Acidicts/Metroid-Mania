class AddMultiplierToShipRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :ship_requests, :multiplier, :float, default: 1.0, null: false
  end
end
