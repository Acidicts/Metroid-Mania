class AddShippedAtToProjects < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:projects)

    add_column :projects, :shipped_at, :datetime unless column_exists?(:projects, :shipped_at)
  end
end
