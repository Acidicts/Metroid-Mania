class AddGenericItemFieldsToProductsAndOrders < ActiveRecord::Migration[6.1]
  def change
    # Products: link, cost (credits), variable grants and conversion ratio
    add_column :products, :link, :string
    add_column :products, :cost_credits, :float
    add_column :products, :variable_grant, :boolean, default: false, null: false
    add_column :products, :grant_min_cents, :integer
    add_column :products, :grant_max_cents, :integer
    add_column :products, :credits_per_dollar, :float

    # Orders: store the chosen grant amount (in cents) and keep cost as credits charged
    add_column :orders, :grant_amount_cents, :integer
  end
end
