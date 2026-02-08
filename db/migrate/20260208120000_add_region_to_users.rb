class AddRegionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :region, :string
  end
end
