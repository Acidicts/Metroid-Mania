class AllowNullUserOnAudits < ActiveRecord::Migration[7.1]
  def change
    # Make audits.user_id nullable to allow nullifying when users are destroyed
    change_column_null :audits, :user_id, true
  end
end
