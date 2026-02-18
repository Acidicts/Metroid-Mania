class AddLimitedAndStockToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :limited, :boolean, default: false, null: false
    add_column :products, :stock, :integer, default: 0, null: true
  end
end
