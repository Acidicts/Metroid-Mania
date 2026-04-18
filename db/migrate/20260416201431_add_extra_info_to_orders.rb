class AddExtraInfoToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :extra_info, :string
  end
end
