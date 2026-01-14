class CreateAudits < ActiveRecord::Migration[7.1]
  def change
    create_table :audits do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: true, foreign_key: true
      t.string :action, null: false

      # Use jsonb where available (Postgres); fall back to json/text for SQLite
      if connection.adapter_name.downcase.include?('postgres')
        t.jsonb :details, default: {}
      else
        t.json :details, default: {}
      end

      t.timestamps
    end

    add_index :audits, :action
    add_index :audits, :created_at
  end
end
