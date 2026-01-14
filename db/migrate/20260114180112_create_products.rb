class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.integer :steam_app_id
      t.float :price_currency
      t.integer :steam_price_cents

      t.timestamps
    end
  end
end
