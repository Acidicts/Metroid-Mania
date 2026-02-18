class AddCreditOffsetToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :credit_offset, :float, default: 0.0, null: false
  end
end
