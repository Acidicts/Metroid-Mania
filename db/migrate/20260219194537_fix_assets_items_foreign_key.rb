class FixAssetsItemsForeignKey < ActiveRecord::Migration[8.1]
  def change
    # Remove incorrect foreign key to projects table if it exists
    if foreign_key_exists?(:assets_items, :projects)
      remove_foreign_key :assets_items, :projects
    end

    # Add correct foreign key to assets_projects table if missing
    unless foreign_key_exists?(:assets_items, :assets_projects, column: :project_id)
      add_foreign_key :assets_items, :assets_projects, column: :project_id
    end
  end
end
