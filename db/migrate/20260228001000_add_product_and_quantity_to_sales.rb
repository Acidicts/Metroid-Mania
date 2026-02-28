class AddProductAndQuantityToSales < ActiveRecord::Migration[6.1]
  def change
    add_reference :sales, :product, foreign_key: true, null: true
    add_column :sales, :quantity, :integer, null: false, default: 1
  end
end
