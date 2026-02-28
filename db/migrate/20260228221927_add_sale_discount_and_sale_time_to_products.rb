class AddSaleDiscountAndSaleTimeToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :sale_discount, :float, default: 0.0, null: false
    add_column :products, :sale_time, :date
  end
end
