class AddApprovedSecondsToShip < ActiveRecord::Migration[8.1]
  def change
    add_column :ships, :approved_seconds, :integer
  end
end
