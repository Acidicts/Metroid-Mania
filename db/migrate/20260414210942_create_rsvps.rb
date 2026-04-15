class CreateRsvps < ActiveRecord::Migration[8.1]
  def change
    create_table :rsvps do |t|
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
