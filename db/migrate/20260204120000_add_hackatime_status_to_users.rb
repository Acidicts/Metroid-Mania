class AddHackatimeStatusToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :hackatime_trust_status, :string
    add_column :users, :hackatime_synced_at, :datetime
    add_index :users, :hackatime_trust_status
  end
end
