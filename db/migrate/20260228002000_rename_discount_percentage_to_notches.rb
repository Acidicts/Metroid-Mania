class RenameDiscountPercentageToNotches < ActiveRecord::Migration[6.1]
  def change
    rename_column :sales, :discount_percentage, :discount_notches
    change_column :sales, :discount_notches, :integer, null: false, default: 0
  end
end
