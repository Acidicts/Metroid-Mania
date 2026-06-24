class AddSystemToOrder < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :system, :boolean, default: false, null: false
  end
end
