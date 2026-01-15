class AddShipRequestedAtAndCreditsToProjectsFix < ActiveRecord::Migration[8.1]
  def change
    return unless table_exists?(:projects)

    add_column :projects, :ship_requested_at, :datetime unless column_exists?(:projects, :ship_requested_at)
    add_column :projects, :credits_per_hour, :integer unless column_exists?(:projects, :credits_per_hour)
  end
end
