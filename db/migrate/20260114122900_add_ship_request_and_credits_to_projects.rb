class AddShipRequestAndCreditsToProjects < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:projects, :ship_requested_at)
      add_column :projects, :ship_requested_at, :datetime
    end

    unless column_exists?(:projects, :credits_per_hour)
      add_column :projects, :credits_per_hour, :integer
    end
  end
end
