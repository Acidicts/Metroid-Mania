class AddDetailsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :description, :text
    add_column :projects, :readme_url, :string
  end
end
