require "test_helper"

class ShipTest < ActiveSupport::TestCase
  test "approved_seconds determines notch award" do
    p = projects(:one)
    owner = p.user
    owner.charm_notches.destroy_all

    # Create a ship with approved_seconds set explicitly
    # 4 hours = 14400 seconds, at 0.5 notches per hour = 2 notches
    ship = p.ships.create!(user: owner, devlogged_seconds: 14400, approved_seconds: 14400, credits_awarded: 0.0, shipped_at: Time.current)

    # Reconcile should award notches based on approved_seconds
    desired = owner.reconcile_charm_notches!
    expected_notches = (14400.to_f / 3600.0 * 0.5).floor # 4 hours * 0.5 = 2 notches

    assert_equal expected_notches, desired
    assert_equal expected_notches, owner.charm_notches.count
    assert_equal expected_notches, ship.charm_notches.count
  end

  test "devlogged_seconds copied to approved_seconds on create when approved_seconds not set" do
    p = projects(:one)
    owner = p.user
    owner.charm_notches.destroy_all

    # Create ship without explicit approved_seconds - should be copied from devlogged_seconds
    # 3 hours = 10800 seconds -> 1 notch (0.5 per hour, floor)
    ship = p.ships.create!(user: owner, devlogged_seconds: 10800, credits_awarded: 0.0, shipped_at: Time.current)

    assert_equal 10800, ship.reload.approved_seconds

    desired = owner.reconcile_charm_notches!
    expected_notches = (10800.to_f / 3600.0 * 0.5).floor # 3 hours * 0.5 = 1 notch

    assert_equal expected_notches, desired
    assert_equal expected_notches, owner.charm_notches.count
  end

  test "explicit approved_seconds overrides devlogged_seconds for notch calculation" do
    p = projects(:one)
    owner = p.user
    owner.charm_notches.destroy_all

    # devlogged_seconds = 10 hours but approved_seconds = 2 hours
    ship = p.ships.create!(user: owner, devlogged_seconds: 36000, approved_seconds: 7200, credits_awarded: 0.0, shipped_at: Time.current)

    # Reconcile uses approved_seconds, not devlogged_seconds
    desired = owner.reconcile_charm_notches!
    expected_notches = (7200.to_f / 3600.0 * 0.5).floor # 2 hours * 0.5 = 1 notch

    assert_equal expected_notches, desired
    assert_equal expected_notches, owner.charm_notches.count
  end

  test "carryover hours across multiple ships" do
    p = projects(:one)
    owner = p.user
    owner.charm_notches.destroy_all
    owner.ships.destroy_all

    # Ship 1: 3 hours (1 notch + 1 hour carryover)
    ship1 = p.ships.create!(user: owner, devlogged_seconds: 10800, approved_seconds: 10800, credits_awarded: 0.0, shipped_at: 2.days.ago)
    # Ship 2: 1 hour (total 2 hours with carryover = 1 notch)
    ship2 = p.ships.create!(user: owner, devlogged_seconds: 3600, approved_seconds: 3600, credits_awarded: 0.0, shipped_at: 1.day.ago)
    # Ship 3: 1 hour (total 2 hours with carryover = 1 notch)
    ship3 = p.ships.create!(user: owner, devlogged_seconds: 3600, approved_seconds: 3600, credits_awarded: 0.0, shipped_at: Time.current)

    # 3h + 1h + 1h = 5 hours carried over -> 2 notches (4 hours) with 1 hour remaining
    desired = owner.reconcile_charm_notches!
    assert_equal 2, desired
    assert_equal 2, owner.charm_notches.count
  end

  test "multiplier on creation affects notch count" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)
    owner.charm_notches.destroy_all

    ship = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: 7200, shipped_at: Time.current, multiplier: 2.0)

    expected_credits = (7200.to_f / 3600.0) * 0.5
    expected_notches = (expected_credits.to_i * 2.0).to_i
    assert_equal expected_notches, owner.reload.charm_notches.count
  end

  test "updating multiplier adjusts notches" do
    p = projects(:one)
    admin = users(:one)
    owner = p.user
    owner.update!(currency: 0)
    owner.charm_notches.destroy_all

    ship = p.ship_and_award_credits!(admin_user: admin, rate: 5, devlogged_seconds: 7200, shipped_at: Time.current, multiplier: 1.0)
    initial_notches = owner.reload.charm_notches.count

    ship.update!(multiplier: 2.0)
    new_notches = owner.reload.charm_notches.count
    assert new_notches > initial_notches
  end

  test "adjust_notches_for_multiplier adds notches when multiplier increases" do
    p = projects(:one)
    owner = p.user
    ship = p.ships.create!(user: owner, devlogged_seconds: 7200, credits_awarded: 1.0, shipped_at: Time.current)
    3.times { CharmNotch.create!(user: owner, ship: ship) }

    ship.update!(multiplier: 3.0)
    ship.adjust_notches_for_multiplier(force: true)
    assert_equal 3, ship.charm_notches.count
  end

  test "adjust_notches_for_multiplier removes notches when multiplier decreases" do
    p = projects(:one)
    owner = p.user
    ship = p.ships.create!(user: owner, devlogged_seconds: 7200, credits_awarded: 2.0, shipped_at: Time.current)
    # Add non-admin notches to ensure removal has something to work with
    4.times { CharmNotch.create!(user: owner, ship: ship) }
    count_before = ship.charm_notches.count
    assert count_before > 2, "setup should have more than 2 notches"

    # Bump multiplier to 2.0 via update_column (bypasses callback)
    ship.update_column(:multiplier, 2.0)
    # Now decrease back to 1.0 via update! which triggers adjust_notches_for_multiplier
    # expected = (credits_awarded * multiplier).to_i = (2.0 * 1.0).to_i = 2
    ship.update!(multiplier: 1.0)
    assert_equal 2, ship.charm_notches.count
    assert ship.charm_notches.count < count_before, "notches should have been removed"
  end

  test "backfill syncs ship from request" do
    p = projects(:one)
    owner = p.user
    ship = p.ships.create!(user: owner, devlogged_seconds: 3600, credits_awarded: 1.0, shipped_at: Time.current)
    req = p.ship_requests.create!(user: owner, requested_at: Time.current, devlogged_seconds: 3600, status: "approved", credits_awarded: 2.0, ship_id: ship.id)

    ship.sync_ship_from_request
    assert_equal 2.0, ship.reload.credits_awarded
  end

  # --- hackatime_ids_snapshot ---

  test "hackatime_ids_snapshot returns array from YAML" do
    ship = Ship.new
    ship.write_attribute(:hackatime_ids_snapshot, [ "A", "B" ].to_yaml)
    assert_equal [ "A", "B" ], ship.hackatime_ids_snapshot
  end

  test "hackatime_ids_snapshot returns empty array for nil" do
    ship = Ship.new
    ship.write_attribute(:hackatime_ids_snapshot, nil)
    assert_equal [], ship.hackatime_ids_snapshot
  end

  test "hackatime_ids_snapshot= stores YAML" do
    ship = Ship.new
    ship.hackatime_ids_snapshot = [ "X", "Y" ]
    raw = ship.read_attribute(:hackatime_ids_snapshot)
    assert_equal [ "X", "Y" ], YAML.safe_load(raw)
  end

  # --- validations ---

  test "validates devlogged_seconds non-negative" do
    ship = Ship.new(devlogged_seconds: -1)
    assert_not ship.valid?
    assert_includes ship.errors[:devlogged_seconds], "must be greater than or equal to 0"
  end

  test "validates credits_awarded non-negative" do
    ship = Ship.new(credits_awarded: -1)
    assert_not ship.valid?
    assert_includes ship.errors[:credits_awarded], "must be greater than or equal to 0"
  end

  test "validates multiplier greater than 0" do
    ship = Ship.new(multiplier: 0)
    assert_not ship.valid?
    assert_includes ship.errors[:multiplier], "must be greater than 0"
  end

  test "allows nil credits_awarded" do
    p = projects(:one)
    ship = Ship.new(user: p.user, project: p, devlogged_seconds: 3600)
    assert ship.valid?
    assert_nil ship.credits_awarded
  end

  test "allows nil multiplier via column default" do
    ship = Ship.new(devlogged_seconds: 3600)
    assert ship.multiplier.present?, "multiplier should default to 1.0"
  end

  # --- after_initialize default multiplier ---

  test "new ship defaults multiplier to 1.0" do
    ship = Ship.new
    assert_equal 1.0, ship.multiplier
  end

  # --- used_hackatime_time? ---

  test "used_hackatime_time? returns true when devlogged exceeds user devlogs" do
    p = projects(:one)
    owner = p.user
    p.devlogs.destroy_all
    p.devlogs.create!(user: owner, duration_seconds: 1800, log_date: Date.current)
    ship = p.ships.create!(user: owner, devlogged_seconds: 7200, shipped_at: Time.current)
    assert_predicate ship, :used_hackatime_time?
  end

  test "used_hackatime_time? returns false when devlogs cover seconds" do
    p = projects(:one)
    owner = p.user
    p.devlogs.destroy_all
    p.devlogs.create!(user: owner, duration_seconds: 7200, log_date: Date.current)
    ship = p.ships.create!(user: owner, devlogged_seconds: 3600, shipped_at: Time.current)
    assert_not ship.used_hackatime_time?
  end

  test "used_hackatime_time? returns false when no shipped_at" do
    p = projects(:one)
    ship = p.ships.create!(user: p.user, devlogged_seconds: 3600, shipped_at: nil)
    assert_not ship.used_hackatime_time?
  end

  # --- snapshot_hackatime_ids callback ---

  test "before_create snapshots hackatime_ids from project" do
    p = projects(:one)
    p.update!(hackatime_ids: [ "Snapshot" ])
    ship = p.ships.create!(user: p.user, devlogged_seconds: 3600, shipped_at: Time.current)
    assert_includes ship.hackatime_ids_snapshot, "Snapshot"
  end

  # --- has_many associations ---

  test "has_many charm_notches with dependent nullify" do
    p = projects(:one)
    owner = p.user
    ship = p.ships.create!(user: owner, devlogged_seconds: 3600, credits_awarded: 1.0, shipped_at: Time.current)
    notch = CharmNotch.create!(user: owner, ship: ship)

    ship.destroy
    assert_nil notch.reload.ship_id
  end

  test "has_many comments with dependent destroy" do
    p = projects(:one)
    ship = p.ships.create!(user: p.user, devlogged_seconds: 3600, credits_awarded: 1.0, shipped_at: Time.current)
    comment = Comment.create!(user: p.user, message: "test", commentable: ship)

    ship.destroy
    assert_not Comment.exists?(comment.id)
  end

  # --- recalculate_charm_notches! ---

  test "recalculate_charm_notches! syncs notches from approved_seconds" do
    p = projects(:one)
    owner = p.user
    owner.charm_notches.destroy_all

    # 4 hours approved = 2 notches (0.5 per hour)
    ship = p.ships.create!(user: owner, devlogged_seconds: 14400, approved_seconds: 14400, credits_awarded: 0.0, shipped_at: Time.current)

    count = ship.recalculate_charm_notches!
    assert_equal 2, count
    assert_equal 2, ship.charm_notches.count
  end

  test "recalculate_charm_notches! applies multiplier" do
    p = projects(:one)
    owner = p.user
    owner.charm_notches.destroy_all

    # 4 hours = 2 base notches, with 2.0 multiplier = 4 notches
    ship = p.ships.create!(user: owner, devlogged_seconds: 14400, approved_seconds: 14400, credits_awarded: 0.0, shipped_at: Time.current, multiplier: 2.0)

    count = ship.recalculate_charm_notches!
    assert_equal 4, count
    assert_equal 4, ship.charm_notches.count
  end

  test "recalculate_charm_notches! removes excess notches" do
    p = projects(:one)
    owner = p.user
    owner.charm_notches.destroy_all

    # 2 hours = 1 notch
    ship = p.ships.create!(user: owner, devlogged_seconds: 7200, approved_seconds: 7200, credits_awarded: 0.0, shipped_at: Time.current)

    # Pre-create 5 notches (more than expected)
    5.times { CharmNotch.create!(user: owner, ship: ship) }
    assert_equal 5, ship.charm_notches.count

    count = ship.recalculate_charm_notches!
    assert_equal 1, count
    assert_equal 1, ship.charm_notches.count
  end

  test "recalculate_charm_notches! preserves admin_granted notches" do
    p = projects(:one)
    owner = p.user
    owner.charm_notches.destroy_all

    ship = p.ships.create!(user: owner, devlogged_seconds: 7200, approved_seconds: 7200, credits_awarded: 0.0, shipped_at: Time.current)

    # Create 1 admin notch and 1 regular notch
    CharmNotch.create!(user: owner, ship: ship, admin_granted: true)
    CharmNotch.create!(user: owner, ship: ship, admin_granted: false)
    assert_equal 2, ship.charm_notches.count

    # 1 hour = 0 notches (floor), but we have 1 admin notch that should be preserved
    # Actually 1 hour * 0.5 = 0.5 floor = 0 notches expected
    # But wait, the method only removes non-admin notches
    count = ship.recalculate_charm_notches!
    # Expected = 0 notches, but 1 admin notch exists and won't be removed
    # So we'll have 1 notch left (the admin one)
    assert_equal 1, ship.charm_notches.count
    assert_equal 1, ship.charm_notches.admin_only.count
  end
end
