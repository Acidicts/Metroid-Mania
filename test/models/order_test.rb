require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "statuses_for_select returns the STATUSES constant" do
    assert_equal Order::STATUSES, Order.statuses_for_select
  end

  test "string-backed status predicates work (pending?)" do
    o = Order.new(status: "pending")
    assert_equal "pending", o.status
    assert_predicate o, :pending?
    refute_predicate o, :shipped?
  end

  test "name formats variable grant orders with USD" do
    p = Product.new(name: "VariableProd", variable_grant: true, grant_min_cents: 100, grant_max_cents: 5000)
    o = Order.new(product: p, grant_amount_cents: 1234)
    assert_equal "VariableProd - $ 12.34", o.name
  end

  test "name formats fixed-price orders with USD" do
    p = Product.new(name: "FixedProd", price_currency: 9.5)
    o = Order.new(product: p)
    assert_equal "FixedProd - $ 9.50", o.name
  end

  test "charm_image_url validation allows valid urls and rejects bad ones" do
    user = users(:one)
    product = products(:two)
    user.adjust_charm_notches!(10)
    # Clean up any existing pending orders for this user+product
    user.orders.where(product: product).where(status: 0).destroy_all
    o = Order.new(user: user, product: product, charm_image_url: "https://example.com/foo.png")
    assert o.valid?

    o.charm_image_url = "not a url"
    refute o.valid?
    assert_includes o.errors[:charm_image_url], "must be a valid URL"
  end

  test "charm_image_url_for_display falls back to product image" do
    p = Product.new(image_url: "http://foo/bar")
    o = Order.new(product: p)
    assert_equal "http://foo/bar", o.charm_image_url_for_display

    o.charm_image_url = "https://explicit/url"
    assert_equal "https://explicit/url", o.charm_image_url_for_display
  end

  test "refund returns errors for non-denied/non-cancelled status" do
    o = Order.new(status: "pending")
    o.refund
    assert_includes o.errors[:status], "can only be set to 'denied' or 'cancelled"
  end

  test "product_notch_cost returns 0 for nil product or user" do
    o = Order.new(user: nil, product: nil)
    assert_equal 0, o.product_notch_cost
  end

  test "fulfilled? returns true for shipped status" do
    o = Order.new(status: "shipped")
    assert_predicate o, :fulfilled?
  end

  test "fufilled? alias works" do
    o = Order.new(status: "shipped")
    assert_predicate o, :fufilled?
  end

  test "find_by_param raises RecordNotFound for invalid id" do
    assert_raises(ActiveRecord::RecordNotFound) { Order.find_by_param("nonexistent") }
  end

  test "set_public_id generates a public_id on save" do
    o = Order.new
    o.send(:set_public_id)
    assert o.public_id.present?
  end

  test "STATUSES constant contains expected statuses" do
    assert_includes Order::STATUSES.map(&:last), "pending"
    assert_includes Order::STATUSES.map(&:last), "shipped"
    assert_includes Order::STATUSES.map(&:last), "denied"
  end

  test "to_param returns public_id" do
    o = Order.new
    o.send(:set_public_id)
    assert_equal o.public_id, o.to_param
  end
end
