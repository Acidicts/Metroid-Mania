require "test_helper"

class Admin::ShipRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: 'admin3@example.com', uid: "admin-#{SecureRandom.uuid}", password: 'password')

    @project = projects(:one)
  end

  test "approve can award credits to specified recipient" do
    sign_in_as(@admin, password: 'password')

    # create a pending ship request with 2 hours of devlogs
    req = @project.ship_requests.create!(user: @project.user, requested_at: Time.current, devlogged_seconds: 2.hours.to_i, status: 'pending')

    recipient = users(:two)
    recipient.update!(currency: 0)

    existing_ship_ids = Ship.where(project: @project).pluck(:id)

    post approve_admin_ship_request_url(req), params: { credits_per_hour: 10, recipient_user_id: recipient.id }
    assert_redirected_to admin_ship_requests_url

    @project.reload

    # ship created and request approved
    req.reload
    assert_equal 'approved', req.status

    ship = Ship.where(project: @project).where.not(id: existing_ship_ids).first
    assert_not_nil ship, "expected a Ship created for project"

    expected_amount = ( ( req.devlogged_seconds.to_f / 3600.0 ) * 10 )
    assert_in_delta expected_amount, ship.credits_awarded.to_f, 0.001

    # credits were awarded to the selected recipient (not necessarily the owner)
    assert_in_delta expected_amount, recipient.reload.currency.to_f, 0.001

    assert_audit_created(action: 'approve_ship_request', project: @project, user: @admin)
  end
end
