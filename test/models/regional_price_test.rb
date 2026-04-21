require "test_helper"

class RegionalPriceTest < ActiveSupport::TestCase
  test "defaults cost to 1" do
    price = RegionalPrice.new
    assert_equal 1, price.cost
  end

  test "defaults enabled to false" do
    price = RegionalPrice.new
    assert_equal false, price.enabled
  end

  test "can persist cost and enabled values" do
    product = products(:one)
    price = RegionalPrice.create!(priceable: product, region: "United States", cost: 10, enabled: true)

    assert_equal 10, price.cost
    assert_equal true, price.enabled
    assert_equal "United States", price.region
  end
end
