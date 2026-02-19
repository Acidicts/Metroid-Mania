class AddUserToAssetsItem < ActiveRecord::Migration[8.1]
  def change
    add_reference :assets_items, :user, null: false, foreign_key: true
  end
end
