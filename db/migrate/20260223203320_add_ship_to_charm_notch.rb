class AddShipToCharmNotch < ActiveRecord::Migration[8.1]
  def change
    add_reference :charm_notches, :ship, null: false, foreign_key: true, default: 0
  end
end
