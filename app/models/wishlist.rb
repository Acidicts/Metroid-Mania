# == Schema Information
#
# Table name: wishlists
#
#  id           :bigint           not null, primary key
#  created_at   :datetime         not null
#  product_ids  :json             default: [], not null
#  updated_at   :datetime         not null
#  user_id      :integer          not null
#
# Indexes
#  index_wishlists_on_user_id  (user_id)
#
class Wishlist < ApplicationRecord
  belongs_to :user

  # store an array of integer ids in a JSON/text column; AR will cast JSON
  # values to Ruby objects automatically so no explicit serialization is needed.

  # convenience wrapper for loading associated Product records

  validate :omit_duplicates, on: :update

  def omit_duplicates
    if product_ids.uniq.length != product_ids.length
      unique_ids = []
      for i in 0...product_ids.length
        if !unique_ids.include?(product_ids[i])
          unique_ids << product_ids[i]
        end
      end
      self.product_ids = unique_ids
    end
  end

  def products
    Product.where(id: product_ids)
  end
end
