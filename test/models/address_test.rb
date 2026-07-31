require "test_helper"

class AddressTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    addr = Address.new(user: users(:one), country: "US - United States", address_line_1: "123 Main St", city: "Springfield", province: "IL", postal_code: "62704")
    assert addr.valid?
  end

  test "belongs_to user" do
    addr = addresses(:one)
    assert_equal users(:one), addr.user
  end

  test "enum country values" do
    addr = addresses(:one)
    assert addr.respond_to?(:country)
  end

  test "has_many orders" do
    addr = addresses(:one)
    assert addr.respond_to?(:orders)
  end
end
