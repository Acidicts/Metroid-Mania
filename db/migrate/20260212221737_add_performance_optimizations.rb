class AddPerformanceOptimizations < ActiveRecord::Migration[8.1]
  def change
    # Add counter cache for ships on projects table
    add_column :projects, :ships_count, :integer, default: 0, null: false
    
    # Add indexes for frequently queried columns
    add_index :devlogs, [:project_id, :created_at], name: 'index_devlogs_on_project_id_and_created_at'
    add_index :ships, [:project_id, :shipped_at], name: 'index_ships_on_project_id_and_shipped_at'
    add_index :users, :slack_id, name: 'index_users_on_slack_id'
    add_index :projects, [:user_id, :deleted_at], name: 'index_projects_on_user_id_and_deleted_at'
    
    # Reset counter caches for existing records
    reversible do |dir|
      dir.up do
        Project.find_each do |project|
          Project.reset_counters(project.id, :ships, :devlogs)
        end
      end
    end
  end
end

