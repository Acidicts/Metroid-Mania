require "test_helper"

class ShipTest < ActiveSupport::TestCase
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
end
