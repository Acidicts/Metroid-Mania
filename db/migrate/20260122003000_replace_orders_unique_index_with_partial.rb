class ReplaceOrdersUniqueIndexWithPartial < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    # Remove the old unique index on (user_id, product_id, status)
    if index_name_exists?(:orders, "index_orders_on_user_product_status")
      remove_index :orders, name: "index_orders_on_user_product_status"
    end

    # Add a partial unique index that only enforces uniqueness for pending orders (status = 0)
    # This keeps the invariant that a user can't have multiple pending orders for the same product
    # while allowing multiple historical denied/shipped orders.
    add_index :orders, [:user_id, :product_id], unique: true, name: 'index_orders_on_user_product_pending_unique', where: "status = 0"
  end

  def down
    # Remove partial index
    if index_name_exists?(:orders, "index_orders_on_user_product_pending_unique")
      remove_index :orders, name: "index_orders_on_user_product_pending_unique"
    end

    # Recreate the old unique index across (user_id, product_id, status)
    add_index :orders, [:user_id, :product_id, :status], unique: true, name: "index_orders_on_user_product_status"
  end
end
