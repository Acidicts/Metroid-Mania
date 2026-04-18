class CreateAccessoryGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :accessory_groups do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
