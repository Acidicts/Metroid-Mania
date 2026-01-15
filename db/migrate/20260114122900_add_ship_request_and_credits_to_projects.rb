class AddShipRequestAndCreditsToProjects < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:projects)

    add_column :projects, :ship_requested_at, :datetime unless column_exists?(:projects, :ship_requested_at)
    add_column :projects, :credits_per_hour, :integer unless column_exists?(:projects, :credits_per_hour)
  end

  def down
    return unless table_exists?(:projects)

    remove_column :projects, :credits_per_hour if column_exists?(:projects, :credits_per_hour)
    remove_column :projects, :ship_requested_at if column_exists?(:projects, :ship_requested_at)
  end
end
