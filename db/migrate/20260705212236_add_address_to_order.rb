class AddAddressToOrder < ActiveRecord::Migration[8.1]
  def change
    add_reference :orders, :address, null: true, foreign_key: true
  end
end
