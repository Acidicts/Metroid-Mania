class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.string :address_line_1
      t.string :address_line_2
      t.string :city
      t.string :province
      t.string :postal_code
      t.integer :country
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
