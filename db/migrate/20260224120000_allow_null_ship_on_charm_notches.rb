class AllowNullShipOnCharmNotches < ActiveRecord::Migration[8.1]
  def change
    # previous migration added ship reference with null: false and default 0, which
    # causes issues when notches are created outside the context of a shipment.
    # Relax the constraint so free notches can exist without an associated ship.
    change_column_default :charm_notches, :ship_id, from: 0, to: nil
    change_column_null :charm_notches, :ship_id, true
  end
end
