class CreateShipRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :ship_requests do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true # requester
      t.string :status, default: 'pending'

      t.float :credits_per_hour
      t.integer :devlogged_seconds
      t.float :credits_awarded

      t.datetime :requested_at
      t.datetime :approved_at
      t.references :processed_by, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
