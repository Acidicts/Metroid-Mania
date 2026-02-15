class AddHackatimeIdsSnapshotToShips < ActiveRecord::Migration[8.1]
  def change
    add_column :ships, :hackatime_ids_snapshot, :text
  end
end