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

  test "reconcile removes orphan notches and respects ship hours with carryover" do
    # clear existing ships and notches (destroy notches first to avoid FK failures)
    @user.charm_notches.destroy_all
    @user.ships.destroy_all

    # create two ships: 3h and 1h
    project = projects(:one)
    ship1 = @user.ships.create!(project: project, user: @user, shipped_at: 1.day.ago, devlogged_seconds: 3.hours.to_i, credits_awarded: 0)
    ship2 = @user.ships.create!(project: project, user: @user, shipped_at: Time.current, devlogged_seconds: 1.hour.to_i, credits_awarded: 0)

    # add an orphan notch (should be removed) and a valid one tied to ship1
    @user.charm_notches.create!(user: @user, ship: nil, charm_slot: nil)
    @user.charm_notches.create!(user: @user, ship: ship1, charm_slot: nil)

    desired = @user.reconcile_charm_notches!

    # 3h ->1 notch leftover1h; +1h -> total4h ->2 notches
    assert_equal 2, desired
    # orphan removed; valid notches plus any created
    assert_equal 2, @user.charm_notches.where.not(ship_id: nil).count
    assert_equal 2, @user.charm_notches.count
  end

    test "reconcile generates notches from single ship hours" do
      @user.charm_notches.destroy_all
      @user.ships.destroy_all
      project = projects(:one)
      ship = @user.ships.create!(project: project, user: @user, shipped_at: Time.current, devlogged_seconds: 195_949, credits_awarded: 0)

      desired = @user.reconcile_charm_notches!
      expected = ((ship.devlogged_seconds.to_f / 3600.0) / 2.0).floor
      assert_equal expected, desired
      assert_equal expected, @user.charm_notches.count
    end

    test "reconcile assigns notches to each ship proportionally" do
      @user.charm_notches.destroy_all
      @user.ships.destroy_all
      project = projects(:one)

      ship1 = @user.ships.create!(project: project, user: @user,
                                  shipped_at: 2.days.ago,
                                  devlogged_seconds: 5.hours.to_i,
                                  credits_awarded: 0)
      ship2 = @user.ships.create!(project: project, user: @user,
                                  shipped_at: 1.day.ago,
                                  devlogged_seconds: 3.hours.to_i,
                                  credits_awarded: 0)

      # compute expected counts the same way the model will
      carry = 0.0
      exp1 = ((ship1.devlogged_seconds.to_f / 3600.0 + carry) / 2.0).floor
      carry = (ship1.devlogged_seconds.to_f / 3600.0 + carry) - exp1 * 2.0
      exp2 = ((ship2.devlogged_seconds.to_f / 3600.0 + carry) / 2.0).floor

      @user.reload
      desired = @user.reconcile_charm_notches!

      assert_equal(exp1 + exp2, desired)
      assert_equal exp1, @user.charm_notches.where(ship: ship1).count
      assert_equal exp2, @user.charm_notches.where(ship: ship2).count
    end

    test "reconcile credits project owner when another user ships" do
      @user.charm_notches.destroy_all
      @user.ships.destroy_all
      project = projects(:one)
      project.update!(user: @user)

      other = users(:two)
      ship = project.ships.create!(user: other, shipped_at: Time.current,
                                   devlogged_seconds: 7.hours.to_i,
                                   credits_awarded: 0)

      # owner has no ships of their own, but should still earn notches
      assert_equal 0, @user.ships.count
      desired = @user.reconcile_charm_notches!
      expected = ((ship.devlogged_seconds.to_f / 3600.0) / 2.0).floor
      assert_equal expected, desired
      assert_equal expected, @user.charm_notches.count
      # and the generated notches should point back to the ship record
      assert_equal expected, ship.charm_notches.count
    end
end
