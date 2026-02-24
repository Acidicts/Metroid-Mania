class AddProjectTagIdToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :project_tag_id, :integer
  end
end
