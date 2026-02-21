class AddNotchCostToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :notch_cost, :integer
  end
end
