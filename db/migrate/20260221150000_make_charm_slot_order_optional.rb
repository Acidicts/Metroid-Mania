class MakeCharmSlotOrderOptional < ActiveRecord::Migration[8.1]
  def up
    change_column_null :charm_slots, :order_id, true
  end

  def down
    # reverting will set any nil order_id to the placeholder order if present,
    # then make the column non-null again.  we create a placeholder if necessary.
    placeholder = Product.find_or_create_by!(name: "Charm slot placeholder") do |p|
      p.stock = 0
      p.limited = false
      p.price_currency = 0.0
    end
    placeholder.save!(validate: false) if placeholder.changed?

    ordr = Order.find_or_create_by!(product: placeholder, status: "shipped", cost: 0.0)

    CharmSlot.where(order_id: nil).update_all(order_id: ordr.id)
    change_column_null :charm_slots, :order_id, false
  end
end
