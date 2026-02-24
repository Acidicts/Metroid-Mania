class AddAdminGrantedToCharmNotches < ActiveRecord::Migration[8.1]
  def change
    add_column :charm_notches, :admin_granted, :boolean, default: false, null: false
    # Backfill any historical records that used ship_id = -1 to mark admin
    # additions.  After the migration the code should stop using -1, but this
    # keeps old data intact.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE charm_notches
          SET admin_granted = TRUE
          WHERE ship_id = -1;
        SQL
      end
    end
  end
end
