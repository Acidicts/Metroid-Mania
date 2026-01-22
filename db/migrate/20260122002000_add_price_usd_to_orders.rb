class AddPriceUsdToOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :orders, :price_usd, :float

    reversible do |dir|
      dir.up do
        # Backfill existing orders with the best-available USD amount
        Order.reset_column_information
        Order.find_each do |o|
          next if o.price_usd.present?
          if o.grant_amount_cents.present?
            o.update_columns(price_usd: o.grant_amount_cents.to_f / 100.0)
          elsif o.product_id.present?
            prod = Product.find_by(id: o.product_id)
            o.update_columns(price_usd: prod&.price_currency) if prod
          end
        end
      end
    end
  end
end
