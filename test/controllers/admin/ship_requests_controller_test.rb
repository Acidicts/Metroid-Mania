require "test_helper"

class Admin::ShipRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: "admin3@example.com", uid: "admin-#{SecureRandom.uuid}", password: "password")

    @project = projects(:one)
  end

  test "approve can award credits to specified recipient" do
    sign_in_as(@admin, password: "password")

    # create a pending ship request with 2 hours of devlogs and a 2× multiplier
    req = @project.ship_requests.create!(user: @project.user, requested_at: Time.current, devlogged_seconds: 2.hours.to_i, status: "pending", multiplier: 2.0)

    recipient = users(:two)
    recipient.update!(currency: 0)
    recipient.charm_notches.destroy_all

    existing_ship_ids = Ship.where(project: @project).pluck(:id)

    post approve_admin_ship_request_url(req), params: { credits_per_hour: 10, recipient_user_id: recipient.id }

    @project.reload

    # ship created and request approved
    req.reload
    assert_equal "approved", req.status
    assert_in_delta 2.0, req.multiplier.to_f, 0.001

    ship = Ship.where(project: @project).where.not(id: existing_ship_ids).first
    assert_not_nil ship, "expected a Ship created for project"
    assert_redirected_to admin_ship_path(ship)

    expected_amount = ((req.devlogged_seconds.to_f / 3600.0) * (10.0 / 20.0))
    assert_in_delta expected_amount, ship.credits_awarded.to_f, 0.001
    assert_in_delta 2.0, ship.multiplier.to_f, 0.001

    # credits were awarded to the ship (recipient receives charm_notches, not currency)
    assert_equal expected_amount, ship.credits_awarded.to_f
    expected_notches = ship.charm_notches.count

    assert_audit_created(action: "approve_ship_request", project: @project, user: @admin)
  end

  test "admin may override multiplier when approving" do
    sign_in_as(@admin, password: "password")

    req = @project.ship_requests.create!(user: @project.user, requested_at: Time.current, devlogged_seconds: 2.hours.to_i, status: "pending", multiplier: 1.0)
    existing_ship_ids = Ship.where(project: @project).pluck(:id)

    recipient = users(:two)
    recipient.update!(currency: 0)

    post approve_admin_ship_request_url(req), params: { credits_per_hour: 10, recipient_user_id: recipient.id, multiplier: 3.0 }

    req.reload
    assert_equal 3.0, req.multiplier.to_f

    ship = Ship.where(project: @project).where.not(id: existing_ship_ids).first
    assert_equal 3.0, ship.multiplier.to_f
    expected_amount = ((req.devlogged_seconds.to_f / 3600.0) * 0.5)
    expected_notches = (expected_amount.to_i * 3)
    assert_equal expected_notches, ship.charm_notches.count
  end

  test "approve respects approved_seconds for notch calculation" do
    sign_in_as(@admin, password: "password")

    # Request has 4 hours devlogged, but admin only approves 2 hours
    req = @project.ship_requests.create!(user: @project.user, requested_at: Time.current, devlogged_seconds: 4.hours.to_i, status: "pending")
    existing_ship_ids = Ship.where(project: @project).pluck(:id)

    # Approve with only 2 hours (7200 seconds)
    post approve_admin_ship_request_url(req), params: { credits_per_hour: 10, approved_seconds: 7200 }

    req.reload
    assert_equal "approved", req.status

    ship = Ship.where(project: @project).where.not(id: existing_ship_ids).first
    assert_not_nil ship

    # 2 hours approved = 1 notch (0.5 per hour, floor)
    assert_equal 7200, ship.approved_seconds
    assert_equal 1, ship.charm_notches.count
  end

  test "reject updates devlog title, clears duration_seconds and makes it re-associable" do
    sign_in_as(@admin, password: "password")

    # create a pending ship request and ensure the system devlog is created
    req = @project.ship_requests.create!(user: @project.user, requested_at: Time.current, devlogged_seconds: 2.hours.to_i, status: "pending")

    d = @project.devlogs.where(ship_request_id: req.id).order(:created_at).first
    assert_not_nil d, "expected a devlog created for ship request"
    assert_equal "Ship request ##{req.id}", d.title
    assert_not_nil d.duration_seconds

    # also create a regular project devlog that was linked to the request (typical flow)
    linked = @project.devlogs.create!(user: @project.user, title: "Work before ship", content: "x", duration_seconds: 1800, log_date: Date.current, ship_request_id: req.id)
    assert_equal req.id, linked.reload.ship_request_id

    post reject_admin_ship_request_url(req)

    req.reload
    d = Devlog.find_by(id: d.id)
    linked.reload

    assert_equal "rejected", req.status
    assert_equal "Rejected ship request ##{req.id}", d.title
    assert_nil d.duration_seconds
    assert_nil d.ship_request_id

    # the previously-linked project devlog should have been dissociated so it can
    # be included in a future ship request
    assert_nil linked.ship_request_id

    assert_audit_created(action: "reject_ship_request", project: @project, user: @admin)
  end
end
