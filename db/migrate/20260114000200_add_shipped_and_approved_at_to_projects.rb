class AddShippedAndApprovedAtToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :shipped, :boolean, default: false, null: false
    add_column :projects, :approved_at, :datetime
  end
end
