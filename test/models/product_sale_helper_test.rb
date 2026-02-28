require "test_helper"

class ProductSaleHelperTest < ActiveSupport::TestCase
  setup do
    # create a separate product so existing fixtures don't pollute
    @product = Product.create!(name: "DummyProduct")
  end

  test "active_sale returns nil when no sale" do
    assert_nil @product.active_sale
  end

  test "active_sale returns sale for matching product" do
    sale = Sale.create!(name: "Promo", discount_notches: 5, product: @product, quantity: 3, starts_at: 1.day.ago, ends_at: 1.day.from_now)
    assert_equal sale, @product.active_sale
    assert_equal sale, @product.active_sale(3)
    assert_nil @product.active_sale(2)
  end

  test "active_sale ignores expired" do
    Sale.create!(name: "Old", discount_notches: 2, product: @product, quantity: 1, starts_at: 3.days.ago, ends_at: 2.days.ago)
    assert_nil @product.active_sale
  end
end
