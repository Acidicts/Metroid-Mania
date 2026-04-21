class AddSetRegionToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :set_region, :string
  end
end
