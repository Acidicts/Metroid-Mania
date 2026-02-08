class AddImageUrlToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :image_url, :string
  end
end