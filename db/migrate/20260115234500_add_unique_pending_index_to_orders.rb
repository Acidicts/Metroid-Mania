class AddUniquePendingIndexToOrders < ActiveRecord::Migration[8.1]
  def up
    # Add a partial unique index to prevent multiple pending orders for the same user/product
    # SQLite and PostgreSQL support partial indexes with WHERE
    add_index :orders, [:user_id, :product_id], unique: true, name: 'index_orders_on_user_product_pending', where: "status = 'pending'"
  end

  def down
    remove_index :orders, name: 'index_orders_on_user_product_pending'
  end
end
