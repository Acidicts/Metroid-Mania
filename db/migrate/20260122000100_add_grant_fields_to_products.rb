class AddGrantFieldsToProducts < ActiveRecord::Migration[6.1]
  def change
    add_column :products, :grant_enabled, :boolean, default: false, null: false
    add_column :products, :grant_amount_cents, :integer
  end
end
