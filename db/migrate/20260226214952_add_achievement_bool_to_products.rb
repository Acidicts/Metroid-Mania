class AddAchievementBoolToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :achievement_bool, :boolean, default: false
  end
end
