class SetDefaultCharmSlotsOnUsers < ActiveRecord::Migration[8.1]
  def up
    # Ensure existing records have a non-null value before adding default
    execute <<~SQL.squish
      UPDATE users SET charm_slots = 0 WHERE charm_slots IS NULL;
    SQL

    change_column_default :users, :charm_slots, from: nil, to: 0
    # Optionally enforce NOT NULL if we want to disallow nulls entirely
    change_column_null :users, :charm_slots, false, 0
  end

  def down
    change_column_null :users, :charm_slots, true
    change_column_default :users, :charm_slots, from: 0, to: nil
  end
end
