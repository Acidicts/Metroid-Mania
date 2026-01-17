class AddStatusToOrders < ActiveRecord::Migration[6.1]
  LEGACY_STRINGS_TO_INT = {
    'pending'   => 0,
    'denied'    => 1,
    'refunded'  => 2
  }.freeze

  INT_TO_LEGACY_STRINGS = LEGACY_STRINGS_TO_INT.invert.freeze

  def up
    adapter = ActiveRecord::Base.connection.adapter_name.to_s.downcase

    # If no status column exists, add and backfill.
    unless column_exists?(:orders, :status)
      add_column :orders, :status, :integer
      backfill_status_integer_column(:status)
      ensure_status_integer_constraints_and_indexes(adapter, :status)
      return
    end

    col = ActiveRecord::Base.connection.columns(:orders).find { |c| c.name == 'status' }
    if col.sql_type =~ /int/i
      # already integer — ensure constraints/indexes/defaults are present
      backfill_status_integer_column(:status)
      ensure_status_integer_constraints_and_indexes(adapter, :status)
      return
    end

    # Existing column is string-like: migrate to integer safely using a temp column.
    temp       = :status_int_temp
    legacy_col = :status_old

    # 1) create & populate temp int column (idempotent)
    unless column_exists?(:orders, temp)
      add_column :orders, temp, :integer

      execute <<-SQL.squish
        UPDATE orders
        SET #{temp} =
          CASE lower(status)
            #{LEGACY_STRINGS_TO_INT.map { |k, v| "WHEN '#{k.downcase}' THEN #{v}" }.join("\n            ")}
            ELSE 0
          END
      SQL
    end

    # 2) ensure temp int column is sane (non-null/defaulted) before any rename
    backfill_status_integer_column(temp)

    # 3) remove any existing indexes that reference the string `status` column
    #     (SQLite rebuilds the table on rename and will fail if old index definitions
    #      reference a column name that no longer exists).
    remove_indexes_referencing_status(:orders)

    # move the original string column out of the way (idempotent)
    if column_exists?(:orders, :status) && !column_exists?(:orders, legacy_col)
      rename_column :orders, :status, legacy_col
    end

    # 4) put the integer column into :status (idempotent)
    unless column_exists?(:orders, :status)
      rename_column :orders, temp, :status if column_exists?(:orders, temp)
    end

    # 5) now that integer :status exists, add constraints/indexes safely
    ensure_status_integer_constraints_and_indexes(adapter, :status)

    # 6) drop the legacy string column last (if present)
    remove_column :orders, legacy_col if column_exists?(:orders, legacy_col)
  end

  def down
    # Convert integer status back to string values (best-effort)
    return unless column_exists?(:orders, :status)

    # add temp string column
    unless column_exists?(:orders, :status_str)
      add_column :orders, :status_str, :string
      execute <<-SQL.squish
        UPDATE orders
        SET status_str =
          CASE status
            #{INT_TO_LEGACY_STRINGS.map { |k, v| "WHEN #{k} THEN '#{v}'" }.join("\n            ")}
            ELSE 'pending'
          END
      SQL
    end

    change_column_null :orders, :status_str, false
    remove_index :orders, name: 'index_orders_on_status' if index_exists?(:orders, name: 'index_orders_on_status')
    remove_column :orders, :status
    rename_column :orders, :status_str, :status
  end

  private

  def remove_indexes_referencing_status(table)
    # best-effort / idempotent: remove any index that mentions the `status` column
    Array(indexes(table)).each do |idx|
      if idx.columns.include?('status') || (idx.where && idx.where.to_s.match?(/\bstatus\b/))
        remove_index table, name: idx.name if index_exists?(table, name: idx.name)
      end
    end
  rescue => _
    # swallow errors — index cleanup is best-effort to avoid blocking the migration
  end

  def backfill_status_integer_column(column)
    execute <<-SQL.squish
      UPDATE orders
      SET #{column} = 0
      WHERE #{column} IS NULL
    SQL
    change_column_default :orders, column, 0
    change_column_null :orders, column, false
  end

  def ensure_status_integer_constraints_and_indexes(adapter, column)
    # Add a uniqueness constraint that prevents duplicate pending orders.
    # - Postgres: add a partial unique index (efficient).
    # - SQLite and others: add a unique index including status (safe, portable).
    if adapter.include?('postgres')
      unless index_exists?(:orders, name: 'index_orders_on_user_product_pending')
        begin
          add_index :orders, [:user_id, :product_id], unique: true,
                    name: 'index_orders_on_user_product_pending',
                    where: "#{column} = 0"
        rescue ActiveRecord::StatementInvalid
          # best-effort: fall back to a 3-column index if partial index creation fails
          add_index :orders, [:user_id, :product_id, column], unique: true, name: 'index_orders_on_user_product_status' unless index_exists?(:orders, name: 'index_orders_on_user_product_status')
        end
      end
    else
      # SQLite and other adapters: partial indexes are either unsupported or brittle across versions.
      unless index_exists?(:orders, name: 'index_orders_on_user_product_status')
        add_index :orders, [:user_id, :product_id, column], unique: true, name: 'index_orders_on_user_product_status'
      end
    end

    # Add a simple index on status (idempotent). Wrap in rescue to avoid migration abort on odd sqlite constraints.
    begin
      add_index :orders, column, name: 'index_orders_on_status' unless index_exists?(:orders, name: 'index_orders_on_status')
    rescue ActiveRecord::StatementInvalid
      # ignore — index is best-effort in strange/partial-schema states
    end
  end
end
