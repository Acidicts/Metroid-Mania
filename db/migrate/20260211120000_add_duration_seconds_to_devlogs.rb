class AddDurationSecondsToDevlogs < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    add_column :devlogs, :duration_seconds, :integer
    Devlog.reset_column_information
    say_with_time "Backfilling duration_seconds from duration_minutes" do
      Devlog.find_each do |d|
        if d.duration_seconds.nil? && d.duration_minutes.present?
          d.update_columns(duration_seconds: d.duration_minutes.to_i * 60)
        end
      end
    end
  end

  def down
    remove_column :devlogs, :duration_seconds
  end
end
