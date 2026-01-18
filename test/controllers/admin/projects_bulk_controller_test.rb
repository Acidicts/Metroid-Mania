require "test_helper"

class Admin::ProjectsBulkControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: 'admin-bulk@example.com', password: 'password')
    sign_in_as(@admin, password: 'password')

    @p1 = projects(:one)
    @p2 = projects(:two)
  end

  test "bulk set status and credits" do
    # Use per-project credits in this test to simulate the issue
    post admin_bulk_update_admin_projects_url, params: { project_ids: [@p1.id], "credits_for_#{@p1.id}" => 5, "status_for_#{@p1.id}" => 'approved' }
    assert_redirected_to admin_projects_url

    @p1.reload

    assert_equal 'approved', @p1.status
    assert_equal 5, @p1.credits_per_hour

    # credit awarded to project owner and recorded on a Ship
    owner = users(:one)
    owner.reload
    ship = Ship.where(project: @p1).order(created_at: :desc).first
    assert_not_nil ship, 'expected a Ship row when awarding credits during bulk approval'
    assert_in_delta ship.credits_awarded.to_f, owner.currency.to_f, 0.001

    # audits recorded
    assert_audit_created(action: 'bulk_set_status', project: @p1, user: @admin)
    assert_audit_created(action: 'credit_awarded', project: @p1, user: @admin)
  end
end
