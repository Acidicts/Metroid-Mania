class FixAssetsItemsForeignKey < ActiveRecord::Migration[8.1]
  def change
    # Remove incorrect foreign key to projects table
    remove_foreign_key :assets_items, :projects
    
    # Add correct foreign key to assets_projects table
    add_foreign_key :assets_items, :assets_projects, column: :project_id
  end
end
