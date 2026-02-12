class AddDevlogsCountToProjects < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:projects, :devlogs_count)
      add_column :projects, :devlogs_count, :integer, default: 0, null: false
    end

    reversible do |dir|
      dir.up do
        # Recompute existing counters in case the new column was added or values are stale
        Project.find_each do |project|
          Project.reset_counters(project.id, :devlogs)
        end
      end
    end
  end
end
