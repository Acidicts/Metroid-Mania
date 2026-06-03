class AddDailyGoalToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :daily_goal_seconds, :integer, default: 0, null: false
  end
end
