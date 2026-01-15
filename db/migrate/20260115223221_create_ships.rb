class CreateShips < ActiveRecord::Migration[8.1]
  def change
    create_table :ships do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :shipped_at
      t.integer :devlogged_seconds
      t.float :credits_awarded

      t.timestamps
    end
  end
end
