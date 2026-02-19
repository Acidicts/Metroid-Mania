class CreateSpritesheets < ActiveRecord::Migration[8.1]
  def change
    create_table :spritesheets do |t|
      t.references :assets_item, null: false, foreign_key: { to_table: :assets_items }
      t.string :url
      t.string :name

      t.timestamps
    end
  end
end
