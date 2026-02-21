class RenameCharmslotIdOnCharmNotches < ActiveRecord::Migration[8.1]
  def change
    # this handles both fresh installs and existing databases that already ran the
    # original migration with the mis-cased reference.
    if column_exists?(:charm_notches, :CharmSlot_id)
      rename_column :charm_notches, :CharmSlot_id, :charm_slot_id
    elsif column_exists?(:charm_notches, :charm_slot_id)
      # nothing to do
    end

    # rebuild the index with correct name
    if index_name_exists?(:charm_notches, "index_charm_notches_on_CharmSlot_id")
      rename_index :charm_notches, "index_charm_notches_on_CharmSlot_id", "index_charm_notches_on_charm_slot_id"
    end

    # ensure foreign key points to the right table
    begin
      remove_foreign_key :charm_notches, name: "fk_rails_..." if foreign_key_exists?(:charm_notches, :CharmSlots)
    rescue ArgumentError
      # ignore if not present
    end
    add_foreign_key :charm_notches, :charm_slots, column: :charm_slot_id
  end
end
