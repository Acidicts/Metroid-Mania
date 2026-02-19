class RenameProjectRefToAssetsProjectOnAssetsItems < ActiveRecord::Migration[8.1]
  def up
    # add new reference
    add_reference :assets_items, :assets_project, foreign_key: true

    # copy existing project_id values to assets_project_id
    execute <<-SQL.squish
      UPDATE assets_items SET assets_project_id = project_id
    SQL

    # remove old foreign key + column
    remove_reference :assets_items, :project, foreign_key: true
  end

  def down
    add_reference :assets_items, :project, foreign_key: true
    execute <<-SQL.squish
      UPDATE assets_items SET project_id = assets_project_id
    SQL
    remove_reference :assets_items, :assets_project, foreign_key: true
  end
end
