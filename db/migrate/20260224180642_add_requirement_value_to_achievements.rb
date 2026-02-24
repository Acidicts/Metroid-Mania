class AddRequirementValueToAchievements < ActiveRecord::Migration[8.1]
  def change
    add_column :achievements, :requirement_value, :decimal
  end
end
