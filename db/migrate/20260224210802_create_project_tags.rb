class CreateProjectTags < ActiveRecord::Migration[8.1]
  def change
    create_table :project_tags do |t|
      t.references :project, null: false, foreign_key: true
      t.string :tag_string

      t.timestamps
    end
  end
end
