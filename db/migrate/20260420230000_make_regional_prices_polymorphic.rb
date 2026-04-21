class MakeRegionalPricesPolymorphic < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class RegionalPrice < ActiveRecord::Base
    self.table_name = "regional_prices"
  end

  def up
    unless column_exists?(:regional_prices, :priceable_type) && column_exists?(:regional_prices, :priceable_id)
      add_reference :regional_prices, :priceable, polymorphic: true, index: true
    end

    reversible do |dir|
      dir.up do
        RegionalPrice.reset_column_information
        RegionalPrice.find_each do |price|
          price.update_columns(priceable_type: "Product", priceable_id: price.product_id)
        end
      end
    end

    change_column_null :regional_prices, :priceable_type, false
    change_column_null :regional_prices, :priceable_id, false

    remove_foreign_key :regional_prices, :products if foreign_key_exists?(:regional_prices, :products)
    remove_reference :regional_prices, :product, null: false if column_exists?(:regional_prices, :product_id)
  end

  def down
    add_reference :regional_prices, :product, null: false, foreign_key: true

    reversible do |dir|
      dir.down do
        RegionalPrice.reset_column_information
        RegionalPrice.find_each do |price|
          next unless price.priceable_type == "Product"
          price.update_columns(product_id: price.priceable_id)
        end
      end
    end

    remove_reference :regional_prices, :priceable, polymorphic: true, index: true
  end
end
