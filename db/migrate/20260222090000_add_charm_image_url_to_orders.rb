class AddCharmImageUrlToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :charm_image_url, :string
  end
end
