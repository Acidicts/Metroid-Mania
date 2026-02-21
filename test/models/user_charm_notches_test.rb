require "test_helper"

class UserCharmNotchesTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    # start from a clean slate: remove any existing free notches
    @user.charm_notches.where(charm_slot_id: nil).destroy_all
  end

  test "increasing target adds free notches" do
    assert_equal 0, @user.free_notches
    @user.adjust_charm_notches!(3)
    assert_equal 3, @user.free_notches
    # each notch should live in a unique slot
    assert_equal 3, @user.charm_slots.where(order_id: nil).count
  end

  test "decreasing target removes only free notches" do
    @user.adjust_charm_notches!(5)
    assert_equal 5, @user.free_notches

    @user.adjust_charm_notches!(2)
    assert_equal 2, @user.free_notches,
                 "should delete the appropriate number of unlinked notches"
  end

  test "negative targets raise" do
    assert_raises(ArgumentError) { @user.adjust_charm_notches!(-1) }
  end
end
