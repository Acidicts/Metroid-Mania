require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "dependent orders prevents destruction" do
    prod = products(:one)
    # fixture `one` has an associated order; destruction should be blocked
    assert_not prod.destroy
    assert_includes prod.errors[:base].join, "orders"
  end

  test "can destroy product with no orders" do
    p = Product.create!(name: "Temp", price_currency: 0.5)
    assert p.destroy
  end

  test "achievement association uses foreign key on product" do
    # product should belong to an achievement rather than the reverse.
    ach = achievements(:one)
    prod_with = Product.create!(name: "With", price_currency: 1.0, achievement: ach)
    assert_equal ach, prod_with.achievement

    prod_without = Product.create!(name: "Without", price_currency: 2.0)
    assert_nil prod_without.achievement
  end
end
