class AddDefaultAddressIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :default_address_id, :string
  end
end
