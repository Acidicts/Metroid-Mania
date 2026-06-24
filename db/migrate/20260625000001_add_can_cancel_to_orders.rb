class AddCanCancelToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :can_cancel, :boolean, default: true, null: false
  end
end
