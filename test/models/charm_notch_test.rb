require "test_helper"

class CharmNotchTest < ActiveSupport::TestCase
  test "assigned? returns true when charm_slot present" do
    slot = CharmSlot.create!(user: users(:one))
    n = CharmNotch.new(charm_slot: slot, user: users(:one))
    assert_predicate n, :assigned?
  end

  test "assigned? returns false when charm_slot nil" do
    n = CharmNotch.new(charm_slot: nil, user: users(:one))
    assert_not n.assigned?
  end

  test "admin? returns true when admin_granted is true" do
    n = CharmNotch.new(admin_granted: true)
    assert_predicate n, :admin?
  end

  test "admin? returns false by default" do
    n = CharmNotch.new
    assert_not n.admin?
  end

  test "scope non_admin excludes admin notches" do
    user = users(:one)
    admin_n = CharmNotch.create!(user: user, admin_granted: true)
    user_n = CharmNotch.create!(user: user, admin_granted: false)
    assert_includes CharmNotch.non_admin, user_n
    assert_not_includes CharmNotch.non_admin, admin_n
  end

  test "scope admin_only includes only admin notches" do
    user = users(:one)
    admin_n = CharmNotch.create!(user: user, admin_granted: true)
    user_n = CharmNotch.create!(user: user, admin_granted: false)
    assert_includes CharmNotch.admin_only, admin_n
    assert_not_includes CharmNotch.admin_only, user_n
  end

  test "belongs_to user" do
    n = CharmNotch.new(user: users(:one))
    assert_equal users(:one), n.user
  end

  test "belongs_to ship optionally" do
    n = CharmNotch.new
    assert_nil n.ship
  end

  test "belongs_to charm_slot optionally" do
    n = CharmNotch.new
    assert_nil n.charm_slot
  end
end
