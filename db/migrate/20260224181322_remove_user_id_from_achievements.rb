class RemoveUserIdFromAchievements < ActiveRecord::Migration[8.1]
  def change
    remove_index :achievements, :user_id, if_exists: true
    remove_column :achievements, :user_id, :integer
  end
end
