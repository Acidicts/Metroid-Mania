class AllowAdminDuplicatePendingOrders < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    add_column :orders, :admin_created, :boolean, null: false, default: false unless column_exists?(:orders, :admin_created)

    if index_name_exists?(:orders, "index_orders_on_user_product_pending_unique")
      remove_index :orders, name: "index_orders_on_user_product_pending_unique"
    end

    add_index :orders, [ :user_id, :product_id ], unique: true, name: "index_orders_on_user_product_pending_unique", where: "status = 0 AND admin_created = false"
  end

  def down
    if index_name_exists?(:orders, "index_orders_on_user_product_pending_unique")
      remove_index :orders, name: "index_orders_on_user_product_pending_unique"
    end

    remove_column :orders, :admin_created if column_exists?(:orders, :admin_created)

    add_index :orders, [ :user_id, :product_id ], unique: true, name: "index_orders_on_user_product_pending_unique", where: "status = 0"
  end
end
