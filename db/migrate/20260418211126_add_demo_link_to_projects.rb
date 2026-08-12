class AddDemoLinkToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :demo_link, :string, default: nil, null: true
  end
end
