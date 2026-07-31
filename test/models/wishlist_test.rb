require "test_helper"

class WishlistTest < ActiveSupport::TestCase
  test "defaults product_ids to empty array" do
    w = Wishlist.new
    assert_equal [], w.product_ids
  end

  test "can store multiple product ids" do
    w = Wishlist.new(product_ids: [ 1, 2, 3 ])
    assert_equal [ 1, 2, 3 ], w.product_ids
  end

  test "omit_duplicates removes duplicate ids on update" do
    w = Wishlist.create!(user: users(:one), product_ids: [ 1, 2, 2, 3 ])
    w.update!(product_ids: [ 1, 1, 2, 3 ])
    assert_equal [ 1, 2, 3 ], w.reload.product_ids
  end

  test "products returns matching Product records" do
    p = products(:one)
    w = Wishlist.create!(user: users(:one), product_ids: [ p.id ])
    assert_includes w.products, p
  end

  test "products returns empty for unknown ids" do
    w = Wishlist.create!(user: users(:one), product_ids: [ -999 ])
    assert_empty w.products
  end

  test "belongs_to user" do
    w = Wishlist.new(user: users(:one))
    assert_equal users(:one), w.user
  end
end
