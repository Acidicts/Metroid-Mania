class AddShipIdToShipRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :ship_requests, :ship_id, :integer
    add_index :ship_requests, :ship_id
  end
end
