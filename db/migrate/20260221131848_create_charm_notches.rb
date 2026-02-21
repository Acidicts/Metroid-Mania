class CreateCharmNotches < ActiveRecord::Migration[8.1]
  def change
    create_table :charm_notches do |t|
      t.references :user, null: false, foreign_key: true
      t.references :charm_slot, null: false, foreign_key: true

      t.timestamps
    end
  end
end
