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

  test "is_unlocked behavior respects boolean flag and achievement state" do
    user = users(:one)
    prod = Product.create!(name: "P", price_currency: 1.0)

    # default flag is false, should always be unlocked
    assert prod.is_unlocked(user)
    assert prod.is_unlocked(nil), "nil user should still be allowed when flag is off"

    # enabling the requirement without an achievement should make the
    # record invalid and the product effectively locked
    prod.achievement_boolean = true
    assert_not prod.save
    assert_match(/must be selected/, prod.errors[:achievement].join)

    # add an achievement and persist the change; still locked for a user who
    # doesn't have the badge
    ach = achievements(:one)
    prod.achievement = ach
    prod.achievement_boolean = true
    prod.save!
    user.achievements.delete_all
    assert_not prod.is_unlocked(user)

    # grant the achievement and verify unlocking
    user.achievements << ach
    assert prod.is_unlocked(user)
  end
end
