class AdjustOrdersUniqueIndex < ActiveRecord::Migration[7.1]
  def up
    return unless table_exists?(:orders) # guard if orders table is not yet created

    duplicates_sql = <<~SQL
      SELECT 1 FROM orders GROUP BY user_id, product_id HAVING COUNT(*) > 1
    SQL

    duplicates_count = ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM ( #{duplicates_sql} ) AS t"
    ).to_i

    if duplicates_count.positive?
      raise StandardError, "cannot add unique index to orders(user_id, product_id): #{duplicates_count} duplicate group(s) found"
    end

    unless index_exists?(:orders, %i[user_id product_id], unique: true)
      add_index :orders, %i[user_id product_id], unique: true, name: "index_orders_on_user_id_and_product_id"
    end
  end

  def down
    return unless table_exists?(:orders)

    if index_exists?(:orders, %i[user_id product_id], unique: true, name: "index_orders_on_user_id_and_product_id")
      remove_index :orders, name: "index_orders_on_user_id_and_product_id"
    end
  end
end