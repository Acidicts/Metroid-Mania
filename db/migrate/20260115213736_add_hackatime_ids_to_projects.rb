class AddHackatimeIdsToProjects < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:projects)

    add_column :projects, :hackatime_ids, :text unless column_exists?(:projects, :hackatime_ids)

    # Migrate existing single-value `hackatime_id` into `hackatime_ids` (YAML serialized Array)
    if column_exists?(:projects, :hackatime_id)
      migration_project = Class.new(ActiveRecord::Base) do
        self.table_name = "projects"
      end
      migration_project.reset_column_information
      migration_project.find_each do |p|
        h = p.read_attribute(:hackatime_id)
        next if h.blank?
        p.update_column(:hackatime_ids, [h].to_yaml)
      end
    end
  end

  def down
    return unless table_exists?(:projects)

    remove_column :projects, :hackatime_ids if column_exists?(:projects, :hackatime_ids)
  end
end
