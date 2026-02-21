require "test_helper"

class OrderTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "statuses_for_select returns the STATUSES constant" do
    assert_equal Order::STATUSES, Order.statuses_for_select
  end

  test "string-backed status predicates work (pending?)" do
    o = Order.new(status: "pending")
    assert_equal "pending", o.status
    assert_predicate o, :pending?
    refute_predicate o, :shipped?
  end

  test "statuses_for_select does not call an incompatible statuses method" do
    # simulate a broken/odd-arity statuses method that would previously cause class-eval errors
    Order.define_singleton_method(:statuses) { |*_args| raise "should not be called" }

    begin
      assert_equal Order::STATUSES, Order.statuses_for_select
    ensure
      # restore environment
      Order.singleton_class.send(:remove_method, :statuses) rescue nil
    end
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
    o = Order.new
    o.charm_image_url = "https://example.com/foo.png"
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
end
