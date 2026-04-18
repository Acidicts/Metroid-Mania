class CreateAccessories < ActiveRecord::Migration[8.1]
  def change
    create_table :accessories do |t|
      t.references :accessory_group, null: false, foreign_key: true
      t.integer :cost
      t.string :name

      t.timestamps
    end
  end
end
