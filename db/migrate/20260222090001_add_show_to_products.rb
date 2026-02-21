class AddShowToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :show, :boolean, default: true
  end
end
