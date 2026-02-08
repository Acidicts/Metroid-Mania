class AddAmountSpentToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :amount_spent, :float, default: 0.0, null: false
  end
end
