class CreateDevlogs < ActiveRecord::Migration[8.1]
  def change
    create_table :devlogs do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title
      t.text :content
      t.date :log_date
      t.integer :duration_minutes

      t.timestamps
    end
  end
end
