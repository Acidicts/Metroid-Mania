class AddRepositoryAndReadmeToAssetsProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :assets_projects, :repository_url, :string
    add_column :assets_projects, :readme_url, :string
  end
end
