class AddPhysicalToProduct < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :physical, :boolean, default: false
  end
end
