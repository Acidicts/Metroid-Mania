class AddHackatimeIdsToAssetsProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :assets_projects, :hackatime_ids, :text
  end
end
