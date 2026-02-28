class AddNotchCostToOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :orders, :notch_cost, :integer, null: true
  end
end
