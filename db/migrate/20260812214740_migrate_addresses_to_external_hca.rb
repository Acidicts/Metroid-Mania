class MigrateAddressesToExternalHca < ActiveRecord::Migration[8.1]
  def up
    # orders.address_id now stores an external HCA address id (string),
    # not a local addresses.id (bigint), so the FK/index tied to the
    # local table must go before the column type changes.
    remove_foreign_key :orders, :addresses if foreign_key_exists?(:orders, :addresses)
    remove_index :orders, :address_id if index_exists?(:orders, :address_id)

    # Old local address_id values are meaningless once addresses live in HCA.
    # Uncomment if you want to clear stale local IDs rather than carry them
    # forward as strings:
    # execute "UPDATE orders SET address_id = NULL"

    change_column :orders, :address_id, :string

    if table_exists?(:addresses)
      remove_foreign_key :addresses, :users if foreign_key_exists?(:addresses, :users)
      drop_table :addresses
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "addresses are managed externally via HCA now; this migration is intentionally not reversible"
  end
end