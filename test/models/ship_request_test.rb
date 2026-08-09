require "test_helper"

class ShipRequestTest < ActiveSupport::TestCase
  # --- Validations ---

  test "valid with required attributes" do
    user = users(:one)
    project = projects(:one)
    req = ShipRequest.new(user: user, project: project, status: "pending", devlogged_seconds: 3600)
    assert req.valid?
  end

  test "validates status inclusion" do
    req = ShipRequest.new(user: users(:one), project: projects(:one), status: "invalid")
    assert_not req.valid?
    assert_includes req.errors[:status], "is not included in the list"
  end

  test "validates multiplier greater than 0" do
    req = ShipRequest.new(user: users(:one), project: projects(:one), multiplier: 0)
    assert_not req.valid?
    assert_includes req.errors[:multiplier], "must be greater than 0"
  end

  test "allows nil multiplier" do
    req = ShipRequest.new(user: users(:one), project: projects(:one), multiplier: nil)
    assert req.valid?
  end

  # --- pending? ---

  test "pending? returns true when status is pending" do
    req = ShipRequest.new(status: "pending")
    assert_predicate req, :pending?
  end

  test "pending? returns false when status is approved" do
    req = ShipRequest.new(status: "approved")
    assert_not req.pending?
  end

  # --- associated_ship ---

  test "associated_ship returns ship by ship_id" do
    user = users(:one)
    project = projects(:one)
    ship = project.ships.create!(user: user, devlogged_seconds: 3600, credits_awarded: 1.0, shipped_at: Time.current)
    req = ShipRequest.create!(user: user, project: project, status: "approved", ship_id: ship.id, approved_at: Time.current)

    assert_equal ship, req.associated_ship
  end

  test "associated_ship returns nil when no project" do
    req = ShipRequest.new(project: nil)
    assert_nil req.associated_ship
  end

  test "associated_ship returns nil when no matching ship" do
    user = users(:one)
    project = projects(:one)
    req = ShipRequest.create!(user: user, project: project, status: "pending", requested_at: Time.current)
    project.ships.destroy_all
    assert_nil req.associated_ship
  end

  # --- effective_credits_awarded ---

  test "effective_credits_awarded returns stored value when present" do
    req = ShipRequest.new(credits_awarded: 5.0)
    assert_equal 5.0, req.effective_credits_awarded
  end

  test "effective_credits_awarded falls back to ship credits" do
    user = users(:one)
    project = projects(:one)
    ship = project.ships.create!(user: user, devlogged_seconds: 3600, credits_awarded: 3.0, shipped_at: Time.current)
    req = ShipRequest.new(credits_awarded: nil, ship_id: ship.id, project: project)
    assert_equal 3.0, req.effective_credits_awarded
  end

  # --- approve! ---

  test "approve! creates a ship and updates status" do
    user = users(:one)
    project = projects(:one)
    project.update!(credits_per_hour: 5)
    req = ShipRequest.create!(user: user, project: project, status: "pending", devlogged_seconds: 3600, requested_at: Time.current)

    ship = req.approve!(admin_user: user, credits_per_hour: 5)
    assert ship.persisted?
    assert_equal "approved", req.reload.status
    assert_equal ship.id, req.ship_id
  end

  test "approve! raises when not pending" do
    req = ShipRequest.create!(user: users(:one), project: projects(:one), status: "approved", devlogged_seconds: 3600)
    assert_raises(RuntimeError) { req.approve!(admin_user: users(:one)) }
  end

  test "approve! applies multiplier" do
    user = users(:one)
    project = projects(:one)
    project.update!(credits_per_hour: 5)
    req = ShipRequest.create!(user: user, project: project, status: "pending", devlogged_seconds: 7200, multiplier: 2.0, requested_at: Time.current)

    ship = req.approve!(admin_user: user, multiplier: 2.0)
    assert_equal 2.0, ship.reload.multiplier.to_f
    assert_equal 2.0, req.reload.multiplier.to_f
  end

  test "approve! with recipient_user_id awards to specified user" do
    admin = users(:admin)
    owner = users(:one)
    project = projects(:one)
    project.update!(credits_per_hour: 5)
    req = ShipRequest.create!(user: owner, project: project, status: "pending", devlogged_seconds: 3600, requested_at: Time.current)

    ship = req.approve!(admin_user: admin, recipient_user_id: admin.id)
    assert ship.persisted?
    assert_equal "approved", req.reload.status
  end

  # --- reject! ---

  test "reject! updates status to rejected" do
    user = users(:one)
    project = projects(:one)
    req = ShipRequest.create!(user: user, project: project, status: "pending", devlogged_seconds: 3600, requested_at: Time.current)

    req.reject!(admin_user: user)
    assert_equal "rejected", req.reload.status
  end

  test "reject! reverses credits when ship exists" do
    user = users(:one)
    project = projects(:one)
    project.update!(credits_per_hour: 5)
    req = ShipRequest.create!(user: user, project: project, status: "pending", devlogged_seconds: 3600, requested_at: Time.current)
    ship = req.approve!(admin_user: user, credits_per_hour: 5)
    assert ship.credits_awarded > 0

    req.reject!(admin_user: user)
    assert_equal 0.0, ship.reload.credits_awarded
  end

  test "reject! destroys charm notches earned from the ship" do
    user = users(:one)
    project = projects(:one)
    project.update!(credits_per_hour: 5)
    req = ShipRequest.create!(user: user, project: project, status: "pending", devlogged_seconds: 7200, requested_at: Time.current)
    ship = req.approve!(admin_user: user, credits_per_hour: 5)
    assert ship.charm_notches.count > 0

    req.reject!(admin_user: user)
    assert_equal 0, ship.reload.charm_notches.count
  end

  test "reject! destroys charm notches earned by a recipient user" do
    admin = users(:admin)
    owner = users(:one)
    recipient = users(:two)
    recipient.charm_notches.destroy_all
    project = projects(:one)
    project.update!(credits_per_hour: 5)
    req = ShipRequest.create!(user: owner, project: project, status: "pending", devlogged_seconds: 7200, requested_at: Time.current)
    ship = req.approve!(admin_user: admin, credits_per_hour: 5, recipient_user_id: recipient.id)
    assert_equal ship.charm_notches.count, recipient.charm_notches.count
    assert ship.charm_notches.count > 0

    req.reject!(admin_user: admin)
    assert_equal 0, ship.reload.charm_notches.count
    assert_equal 0, recipient.reload.charm_notches.count
  end

  test "reject! dissociates devlogs from the request" do
    user = users(:one)
    project = projects(:one)
    req = ShipRequest.create!(user: user, project: project, status: "pending", devlogged_seconds: 3600, requested_at: Time.current)
    devlog = project.devlogs.create!(user: user, duration_seconds: 3600, log_date: Date.current, ship_request: req)

    req.reject!(admin_user: user)
    assert_nil devlog.reload.ship_request_id
  end

  # --- STATUSES ---

  test "STATUSES includes expected values" do
    assert_includes ShipRequest::STATUSES, "pending"
    assert_includes ShipRequest::STATUSES, "approved"
    assert_includes ShipRequest::STATUSES, "rejected"
  end

  # --- recalculate_project_status callback ---

  test "after_create triggers recalculate_project_status" do
    project = projects(:one)
    project.update!(status: "pending")
    req = ShipRequest.create!(user: users(:one), project: project, status: "pending", devlogged_seconds: 3600, requested_at: Time.current)
    assert project.reload.status.present?
  end
end
