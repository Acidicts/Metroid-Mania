require "test_helper"

class SaleTest < ActiveSupport::TestCase
  test "valid with name and notches" do
    s = Sale.new(name: "Flash Sale", discount_notches: 5)
    assert s.valid?
  end

  test "requires name" do
    s = Sale.new(name: nil)
    assert_not s.valid?
    assert_includes s.errors[:name], "can't be blank"
  end

  test "discount_notches >= 0" do
    s = Sale.new(name: "Sale", discount_notches: -1)
    assert_not s.valid?
    assert s.errors[:discount_notches].any?
  end

  test "ends_after_start validates end follows start" do
    s = Sale.new(name: "Sale", starts_at: Time.current, ends_at: 1.day.ago)
    assert_not s.valid?
    assert s.errors[:ends_at].any?
  end

  test "scope active returns currently active sales" do
    s = Sale.create!(name: "Active", starts_at: 1.day.ago, ends_at: 1.day.from_now, discount_notches: 5, quantity: 1)
    assert_includes Sale.active, s
  end

  test "scope active excludes expired sales" do
    s = Sale.create!(name: "Expired", starts_at: 2.days.ago, ends_at: 1.day.ago, discount_notches: 5, quantity: 1)
    assert_not_includes Sale.active, s
  end

  test "belongs_to product optionally" do
    s = Sale.new(name: "Test", discount_notches: 0, product: nil)
    assert s.valid?
  end

  test "product-specific sale requires quantity" do
    s = Sale.new(name: "Sale", discount_notches: 5, product: products(:one), quantity: nil)
    assert_not s.valid?
    assert s.errors[:quantity].any?
  end
end
