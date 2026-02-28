class AddFraudReasonToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :fraud_reason, :string
  end
end
