require "test_helper"

class WishlistTest < ActiveSupport::TestCase
  test "defaults product_ids to empty array" do
    wishlist = Wishlist.new
    assert_equal [], wishlist.product_ids
  end

  test "can store multiple product ids" do
    ids = [ 1, 2, 42 ]
    wishlist = Wishlist.new(product_ids: ids)
    assert_equal ids, wishlist.product_ids
  end
end
