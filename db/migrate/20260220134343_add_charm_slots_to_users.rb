class AddCharmSlotsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :charm_slots, :integer
  end
end
