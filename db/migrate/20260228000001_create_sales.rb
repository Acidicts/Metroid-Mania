class CreateSales < ActiveRecord::Migration[6.1]
  def change
    create_table :sales do |t|
      t.string :name, null: false
      t.text :description
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :discount_percentage, null: false, default: 0

      t.timestamps
    end
  end
end
