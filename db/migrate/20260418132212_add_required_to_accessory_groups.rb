class AddRequiredToAccessoryGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :accessory_groups, :required, :boolean, default: false, null: false
  end
end
