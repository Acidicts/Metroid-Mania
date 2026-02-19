class AddSpritesheetUrlToAssetsItem < ActiveRecord::Migration[8.1]
  def change
    add_column :assets_items, :spritesheet_url, :string
  end
end
