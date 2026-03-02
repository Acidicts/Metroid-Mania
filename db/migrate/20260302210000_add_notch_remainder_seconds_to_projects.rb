class AddNotchRemainderSecondsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :notch_remainder_seconds, :float, default: 0.0, null: false
  end
end
