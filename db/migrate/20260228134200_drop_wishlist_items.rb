class DropWishlistItems < ActiveRecord::Migration[8.1]
  def up
    # remove the table and any foreign key constraints
    drop_table :wishlist_items, if_exists: true
  end

  def down
    # recreate the table in case we need to rollback; use same structure as original
    create_table :wishlist_items do |t|
      t.references :wishlist, foreign_key: true
      t.references :product, foreign_key: true
      t.timestamps
    end
  end
end
