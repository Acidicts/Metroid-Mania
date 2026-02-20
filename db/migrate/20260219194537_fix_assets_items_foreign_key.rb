class FixAssetsItemsForeignKey < ActiveRecord::Migration[8.1]
  def change
    # Remove incorrect foreign key to projects table if it exists
    if foreign_key_exists?(:assets_items, :projects)
      remove_foreign_key :assets_items, :projects
    end

    # Determine which column currently points to assets_projects.  Depending
    # on where in the rename/rollback sequence the database is, it may be
    # `assets_project_id` or `project_id`.
    target_column = if column_exists?(:assets_items, :assets_project_id)
                      :assets_project_id
                    else
                      :project_id
                    end

    # Add the foreign key only if it's not already present on the column we
    # expect to use.  This guards both fresh schema loads and existing
    # databases that have already been migrated.
    unless foreign_key_exists?(:assets_items, :assets_projects, column: target_column)
      add_foreign_key :assets_items, :assets_projects, column: target_column
    end
  end
end
