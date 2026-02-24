class AddRequirementTypeToAchievements < ActiveRecord::Migration[8.1]
  def change
    add_column :achievements, :requirement_type, :string
  end
end
