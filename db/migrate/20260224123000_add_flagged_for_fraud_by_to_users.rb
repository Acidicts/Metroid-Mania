class AddFlaggedForFraudByToUsers < ActiveRecord::Migration[8.1]
  def change
    # track which admin marked a user as fraudulent
    add_reference :users, :flagged_for_fraud_by, foreign_key: { to_table: :users }, index: true
  end
end
