class AddBaseCostToProduct < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :base_cost, :integer, default: 0
  end
end
