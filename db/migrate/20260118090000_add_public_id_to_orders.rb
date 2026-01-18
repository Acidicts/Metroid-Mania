# frozen_string_literal: true

class AddPublicIdToOrders < ActiveRecord::Migration[6.1]
  require 'securerandom'

  def up
    add_column :orders, :public_id, :string
    add_index :orders, :public_id, unique: true

    # Backfill existing orders with generated public_ids
    say_with_time "Backfilling public_id for existing orders" do
      Order.reset_column_information
      Order.find_each do |o|
        next if o.public_id.present?
        o.update_columns(public_id: generate_unique_public_id)
      end
    end
  end

  def down
    remove_index :orders, :public_id if index_exists?(:orders, :public_id)
    remove_column :orders, :public_id if column_exists?(:orders, :public_id)
  end

  private

  def generate_unique_public_id
    loop do
      candidate = "!#{SecureRandom.alphanumeric(6)}"
      break candidate unless Order.where(public_id: candidate).exists?
    end
  end
end
