require "test_helper"

class SaleTest < ActiveSupport::TestCase
  test "valid with name and notches" do
    sale = Sale.new(name: "Test", discount_notches: 10)
    assert sale.valid?
  end

  test "product-specific sale requires quantity" do
    product = products(:one) rescue Product.create!(name: "Foo")
    sale = Sale.new(name: "Bundle", discount_notches: 3, product: product, quantity: nil)
    refute sale.valid?
    assert_includes sale.errors[:quantity], "is not a number"

    sale.quantity = 5
    assert sale.valid?
  end

  test "requires name" do
    sale = Sale.new(discount_notches: 10)
    refute sale.valid?
    assert_includes sale.errors[:name], "can't be blank"
  end

  test "percentage must be 0..100" do
    sale = Sale.new(name: "Bad", discount_notches: -5)
    refute sale.valid?
    assert_includes sale.errors[:discount_notches], "must be greater than or equal to 0"
  end

  test "ends after start" do
    sale = Sale.new(name: "Temporal", starts_at: 1.day.from_now, ends_at: 1.day.ago, discount_notches: 10)
    refute sale.valid?
    assert_includes sale.errors[:ends_at], "must be after the start time"
  end
end
