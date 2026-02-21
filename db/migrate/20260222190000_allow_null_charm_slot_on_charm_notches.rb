class AllowNullCharmSlotOnCharmNotches < ActiveRecord::Migration[8.1]
  def change
    # the domain allows a notch to exist without an attached slot (free
    # notches are represented by slot_id == NULL), but the original
    # migration declared the column as NOT NULL.  this mismatch leads to
    # constraint violations when the code deliberately clears the
    # association, as seen when running `rake data:validate_all`.  make the
    # database match the model intent.
    change_column_null :charm_notches, :charm_slot_id, true
  end
end
