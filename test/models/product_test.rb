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
end
