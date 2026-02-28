class AddProductIdsToWishlists < ActiveRecord::Migration[8.1]
  def change
    # use a JSON column to store an array of product IDs; this works on SQLite
    # and Postgres and avoids adapter-specific `array:` keyword errors.
    add_column :wishlists, :product_ids, :json, default: [], null: false

    # if you'd prefer a join table instead, you can create a separate migration
    # to remove this column and resurrect wishlist_items with product references.
  end
end
