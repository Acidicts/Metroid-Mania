class AddCharmNotchesToUsers < ActiveRecord::Migration[8.1]
  # No database change: users already have many charm_notches via
  # charm_notches.user_id.  The generator ran with the wrong intent and would
  # create a useless users.charm_notches_id column, so this migration is
  # intentionally left empty.
  def change
  end
end
