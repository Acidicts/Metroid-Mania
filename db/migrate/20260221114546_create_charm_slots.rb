class CreateCharmSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :charm_slots do |t|
      t.references :user, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true

      t.timestamps
    end
  end
end
