class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :repository_url
      t.string :status
      t.string :hackatime_id
      t.integer :total_seconds

      t.timestamps
    end
  end
end
