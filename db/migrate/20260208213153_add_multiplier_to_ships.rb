class AddMultiplierToShips < ActiveRecord::Migration[8.1]
  def change
    add_column :ships, :multiplier, :float
  end
end
