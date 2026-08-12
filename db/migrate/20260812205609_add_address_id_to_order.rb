class AddAddressIdToOrder < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :address_id, :string
  end
end
