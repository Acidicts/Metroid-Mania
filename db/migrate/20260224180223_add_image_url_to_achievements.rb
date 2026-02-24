class AddImageUrlToAchievements < ActiveRecord::Migration[8.1]
  def change
    add_column :achievements, :image_url, :string
  end
end
