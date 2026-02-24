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

  test "reconcile does not destroy admin-granted notches" do
    @user.charm_notches.destroy_all
    # create an explicit admin notch using the new flag
    @user.charm_notches.create!(charm_slot: nil, admin_granted: true)

    # running reconciliation with no ships should leave the record untouched
    desired = @user.reconcile_charm_notches!
    assert_equal 0, desired
    assert_equal 1, @user.charm_notches.admin_only.count,
                 "admin notch should survive reconciliation"
  end

  test "adjusting free notches does not delete admin-granted freebies" do
    @user.charm_notches.destroy_all
    # add an admin free notch plus a normal one
    @user.charm_notches.create!(charm_slot: nil, admin_granted: true)
    @user.adjust_charm_notches!(1)
    # current free notches is 2 but one is admin; shrinking target should only
    # remove the non-admin one
    @user.adjust_charm_notches!(0)
    assert_equal 1, @user.charm_notches.admin_only.count
    assert_equal 0, @user.charm_notches.non_admin.count
  end

  test "legacy admin notches (no flag) survive reconciliation when slots exist" do
    @user.charm_notches.destroy_all
    @user.charm_slots.destroy_all

    # simulate an old admin grant: create slot and notch but do not set flag
    @user.charm_slots.create!
    @user.charm_notches.create!(charm_slot: nil)

    # the notch starts unflagged, so naive reconciliation would remove it
    desired = @user.reconcile_charm_notches!
    # desired counts only non-admin notches; in this scenario there are none
    assert_equal 0, desired

    # after reconciliation the record should be converted to admin_granted and kept
    assert_equal 1, @user.charm_notches.admin_only.count
    assert_equal 0, @user.charm_notches.non_admin.count
  end

  test "reconcile deletes stray free notches when no empty slots" do
    @user.charm_notches.destroy_all
    @user.charm_slots.destroy_all

    @user.charm_notches.create!(charm_slot: nil)
    assert_equal 1, @user.charm_notches.count

    @user.reconcile_charm_notches!
    assert_equal 0, @user.charm_notches.count,
                 "unflagged free notches should be cleaned up when there are no slots"
  end

  test "admin flag is applied when controller requests it" do
    @user.charm_notches.destroy_all
    @user.adjust_charm_notches!(2, admin: true)
    assert_equal 2, @user.charm_notches.admin_only.count

    # reducing without admin param should not remove the admin-granted ones
    @user.adjust_charm_notches!(0)
    assert_equal 2, @user.charm_notches.admin_only.count
    assert_equal 0, @user.charm_notches.non_admin.count

    # now reduce using admin flag; this should delete the admin-granted
    # notches because the admin is explicitly requesting a total change.
    @user.adjust_charm_notches!(1, admin: true)
    assert_equal 1, @user.charm_notches.admin_only.count
    assert_equal 1, @user.free_notches
  end

  test "admin adjustment overrides existing free notches rather than accumulating" do
    @user.charm_notches.destroy_all
    # simulate earned notches (non-admin) that should be replaced
    2.times { @user.charm_notches.create!(charm_slot: nil) }
    assert_equal 2, @user.free_notches

    # setting to a higher value creates only the difference
    @user.adjust_charm_notches!(5, admin: true)
    assert_equal 5, @user.free_notches

    # setting to a lower value removes the excess
    @user.adjust_charm_notches!(1, admin: true)
    assert_equal 1, @user.free_notches

    # idempotency: repeating the same target does not change the count
    @user.adjust_charm_notches!(1, admin: true)
    assert_equal 1, @user.free_notches
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
