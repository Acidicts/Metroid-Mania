class AddShippedAndApprovedAtToProjects < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:projects)

    unless column_exists?(:projects, :shipped)
      add_column :projects, :shipped, :boolean, default: false, null: false
    end

    add_column :projects, :approved_at, :datetime unless column_exists?(:projects, :approved_at)
  end

  def down
    return unless table_exists?(:projects)

    remove_column :projects, :approved_at if column_exists?(:projects, :approved_at)
    remove_column :projects, :shipped if column_exists?(:projects, :shipped)
  end
end
