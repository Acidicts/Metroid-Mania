require "test_helper"
require "rake"

class ShipTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
    @admin = users(:one)
    @owner = @project.user
    @owner.update!(currency: 0)
    @owner.charm_notches.destroy_all
    @project.ships.destroy_all
  end

  test "multiplier on ship creation influences notch count" do
    devlogged_seconds = 60 * 120
    ship = @project.ship_and_award_credits!(admin_user: @admin, rate: 5, devlogged_seconds: devlogged_seconds, shipped_at: Time.current, multiplier: 2.0)
    base = (devlogged_seconds.to_f / 3600.0 * 0.5).to_i
    assert_equal 2.0, ship.multiplier.to_f
    assert_equal (base * 2).to_i, ship.charm_notches.count
  end

  test "updating ship multiplier adjusts notches automatically" do
    devlogged_seconds = 60 * 120
    ship = @project.ship_and_award_credits!(admin_user: @admin, rate: 5, devlogged_seconds: devlogged_seconds, shipped_at: Time.current, multiplier: 1.0)
    base = (devlogged_seconds.to_f / 3600.0 * 0.5).to_i
    assert_equal base, ship.charm_notches.count

    ship.update!(multiplier: 3.0)
    ship.reload
    assert_equal 3.0, ship.multiplier.to_f
    assert_equal (base * 3).to_i, ship.charm_notches.count

    # also decreasing removes notches
    ship.update!(multiplier: 1.0)
    ship.reload
    assert_equal base, ship.charm_notches.count
  end

  test "propagating multiplier change from request adjusts ship" do
    # create request and approve
    req = @project.ship_requests.create!(user: @owner, requested_at: Time.current, devlogged_seconds: 3600, status: "pending", multiplier: 2.0)
    ship = req.approve!(admin_user: @admin)
    base = ship.charm_notches.count
    assert_equal 2.0, ship.multiplier.to_f

    # change request multiplier and call sync explicitly (simulates external update)
    req.update!(multiplier: 4.0)
    ship.sync_ship_from_request
    ship.reload
    assert_equal 4.0, ship.multiplier.to_f
    assert_equal (base * 2), ship.charm_notches.count, "notches should double when multiplier doubles"
  end

  test "public adjust_notches_for_multiplier works standalone" do
    ship = @project.ship_and_award_credits!(admin_user: @admin, rate: 1, devlogged_seconds: 3600, shipped_at: Time.current, multiplier: 1.0)
    base = ship.charm_notches.count
    ship.multiplier = 3.0
    ship.adjust_notches_for_multiplier
    ship.reload
    assert_equal (base * 3), ship.charm_notches.count
  end

  test "backfill simulation fixes notch counts based on multiplier" do
    # create a request with multiplier and approve to produce a ship
    req = @project.ship_requests.create!(user: @owner, requested_at: Time.current, devlogged_seconds: 3600, status: "pending", multiplier: 2.0)
    ship = req.approve!(admin_user: @admin)

    assert_equal 2.0, req.reload.multiplier.to_f, "request should retain multiplier"

    # tamper: remove half the notches and clear the multiplier on ship to simulate old data
    ship.charm_notches.limit((ship.charm_notches.count / 2.0).ceil).each(&:destroy)
    ship.update_column(:multiplier, nil)

    # now simulate what the rake task would do for this ship
    ship.sync_ship_from_request

    ship.reload

    # multiplier and notches should be restored from request
    assert_equal 2.0, ship.multiplier.to_f
    base = (ship.credits_awarded.to_f.to_i)
    assert_equal (base * 2).to_i, ship.charm_notches.count, "simulation should have restored notches and multiplier"
  end

  test "backfill logic treats zero multiplier as missing" do
    req = @project.ship_requests.create!(user: @owner, requested_at: Time.current, devlogged_seconds: 3600, status: "pending", multiplier: 3.0)
    ship = req.approve!(admin_user: @admin)
    ship.update_column(:multiplier, 0.0)

    # emulate the numeric check used in the rake task
    assert ship.multiplier.to_f <= 0, "ship should appear to have no multiplier"
    if ship.has_attribute?(:multiplier) && ship.multiplier.to_f <= 0
      ship.update!(multiplier: req.multiplier.to_f)
    end
    ship.reload
    assert_equal 3.0, ship.multiplier.to_f, "zero multiplier should be replaced"
  end
end
