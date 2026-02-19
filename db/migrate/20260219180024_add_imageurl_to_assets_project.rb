class AddImageurlToAssetsProject < ActiveRecord::Migration[8.1]
  def change
    add_column :assets_projects, :image_url, :string, null: true, default: nil
  end
end
