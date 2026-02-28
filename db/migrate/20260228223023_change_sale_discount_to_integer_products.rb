class ChangeSaleDiscountToIntegerProducts < ActiveRecord::Migration[8.1]
  def change
    # convert existing sale_discount values from float to integer
    change_column :products, :sale_discount, :integer
  end
end
