class RenameCharmslotIdOnCharmNotches < ActiveRecord::Migration[8.1]
  def change
    # if an old foreign key exists to the mis‑cased table we must drop it
    # *before* renaming the column so that sqlite doesn’t try to rewrite the
    # table referencing a non‑existent `CharmSlots` table during the copy phase.
    if foreign_key_exists?(:charm_notches, column: :CharmSlot_id)
      remove_foreign_key :charm_notches, column: :CharmSlot_id
    end

    # In sqlite `column_exists?` is case‑insensitive so once we've renamed the
    # column the previous check will continue returning true.  Guard against
    # that by ensuring the _new_ name isn't already present too.
    if column_exists?(:charm_notches, :CharmSlot_id) &&
       !column_exists?(:charm_notches, :charm_slot_id)

      # sqlite has a long‑standing bug where rebuilding a table that has a
      # foreign key to a camel‑cased table name blows up with "no such table:
      # main.CharmSlots".  To keep the normal copy logic happy we temporarily
      # create a dummy table with exactly that name; it's dropped immediately
      # afterwards.  only do this for sqlite since other adapters don't need it.
      tmp_created = false
      if ActiveRecord::Base.connection.adapter_name == 'SQLite'
        unless table_exists?(:"CharmSlots")
          tmp_created = true
          execute <<-SQL.squish
            CREATE TABLE "CharmSlots" (id INTEGER PRIMARY KEY);
          SQL
        end
      end

      rename_column :charm_notches, :CharmSlot_id, :charm_slot_id

      if tmp_created
        execute 'DROP TABLE "CharmSlots"'
      end
    end

    # rebuild the index with correct name
    if index_name_exists?(:charm_notches, "index_charm_notches_on_CharmSlot_id")
      rename_index :charm_notches, "index_charm_notches_on_CharmSlot_id", "index_charm_notches_on_charm_slot_id"
    end

    # add the proper foreign key to the correctly‑named table unless it already
    # exists.  the earlier removal above means this will always be the case on an
    # upgrade path.
    unless foreign_key_exists?(:charm_notches, :charm_slots, column: :charm_slot_id)
      add_foreign_key :charm_notches, :charm_slots, column: :charm_slot_id
    end
  end
end
