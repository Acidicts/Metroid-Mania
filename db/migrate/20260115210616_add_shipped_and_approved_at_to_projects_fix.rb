class AddShippedAndApprovedAtToProjectsFix < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:projects)

    unless column_exists?(:projects, :shipped)
      add_column :projects, :shipped, :boolean, default: false, null: false
    end

    unless column_exists?(:projects, :approved_at)
      add_column :projects, :approved_at, :datetime
    end
  end
end
