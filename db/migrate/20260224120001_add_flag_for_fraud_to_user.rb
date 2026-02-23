class AddFlagForFraudToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :flagged_for_fraud, :boolean, default: false, null: false
  end
end
