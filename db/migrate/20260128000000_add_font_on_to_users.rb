class AddFontOnToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :font_on, :boolean, default: true, null: false
  end
end
