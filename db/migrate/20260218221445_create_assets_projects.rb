class CreateAssetsProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :assets_projects do |t|
      t.string :title
      t.text :description
      t.string :media_type
      t.boolean :shipped
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
