require "test_helper"

class Admin::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: 'admin3@example.com', uid: "admin-#{SecureRandom.uuid}", password: 'password')

    @project = projects(:one)
  end

  test "ship allowed only after a pending request with a new devlog" do
    sign_in_as(@admin, password: 'password')

    # Try shipping before a pending request exists
    post ship_admin_project_url(@project)
    assert_redirected_to admin_dashboard_url
    assert_match /cannot be shipped/i, flash[:alert]

    # Simulate owner request
    @project.update!(status: 'pending', ship_requested_at: Time.current, shipped: false)

    # Still cannot ship until a devlog is created after request (15 minutes required)
    post ship_admin_project_url(@project)
    assert_redirected_to admin_dashboard_url
    assert_match /cannot be shipped/i, flash[:alert]

    # Create a devlog after request with sufficient duration
    post project_devlogs_url(@project), params: { devlog: { title: 'Post-request work', content: 'Work done', duration_minutes: 20 } }

    # Now shipping should succeed
    post ship_admin_project_url(@project)
    assert_redirected_to admin_dashboard_url
    assert @project.reload.shipped
  end

  test "unship works and protected by admin" do
    sign_in_as(@admin, password: 'password')
    @project.update!(status: 'shipped', shipped_at: Time.current, shipped: true)

    post unship_admin_project_url(@project)
    assert_redirected_to admin_dashboard_url
    assert_not @project.reload.shipped
  end

  test "force ship bypasses devlog requirement" do
    sign_in_as(@admin, password: 'password')

    # Ensure project is pending and has no post-request devlog
    @project.update!(status: 'pending', approved_at: nil, shipped: false, ship_requested_at: Time.current)

    post force_ship_admin_project_url(@project)
    assert_redirected_to admin_dashboard_url
    assert @project.reload.shipped
  end

  test "force ship can persist rate and award credits when supplied" do
    sign_in_as(@admin, password: 'password')

    @project.update!(status: 'pending', approved_at: nil, shipped: false, ship_requested_at: Time.current)

    owner = @project.user
    owner.update!(currency: 0)

    # Force-ship with a supplied credits_per_hour
    existing_ship_ids = Ship.where(project: @project).pluck(:id)
    post force_ship_admin_project_url(@project), params: { credits_per_hour: 5 }
    assert_redirected_to admin_dashboard_url

    @project.reload
    assert @project.shipped
    assert_equal 5, @project.credits_per_hour

    ship = Ship.where(project: @project).where.not(id: existing_ship_ids).first
    assert_not_nil ship, "expected a Ship created for project"
    assert_in_delta  ( (ship.devlogged_seconds.to_f/3600.0) * 5 ), ship.credits_awarded.to_f, 0.001

    # ensure owner's currency was updated and the ship records the awarded amount
    assert_in_delta ship.credits_awarded.to_f, owner.reload.currency.to_f, 0.001

    assert_audit_created(action: 'credit_awarded', project: @project, user: @admin)
  end

  test "approve handles credits and marks shipped when there's a request" do
    sign_in_as(@admin, password: 'password')

    # simulate owner request
    @project.update!(status: 'pending', ship_requested_at: Time.current, shipped: false)

    # Create sufficient devlogs to allow approval
    post project_devlogs_url(@project), params: { devlog: { title: 'Pre-approve work', content: 'Work', duration_minutes: 20 } }

    existing_ship_ids = Ship.where(project: @project).pluck(:id)
    post approve_admin_project_url(@project), params: { credits_per_hour: 7 }
    assert_redirected_to admin_dashboard_url
    @project.reload
    assert @project.shipped
    assert_equal 7, @project.credits_per_hour
    assert_nil @project.ship_requested_at

    # audit recorded
    assert_audit_created(action: 'approve', project: @project, user: @admin)

    # credit awarded and reflected on user: only for the post-request devlogs
    @project.reload
    ship = Ship.where(project: @project).where.not(id: existing_ship_ids).first
    assert_not_nil ship, "expected a Ship created for project"
    assert_equal 1, ship.devlogged_seconds / 60 / 20 # sanity: at least reflects minutes
    assert_audit_created(action: 'credit_awarded', project: @project, user: @admin)
  end

  test "ship awards credits when project already has a rate" do
    sign_in_as(@admin, password: 'password')

    owner = @project.user
    owner.update!(currency: 0)

    # project has an existing rate and a pending request
    @project.update!(status: 'pending', ship_requested_at: Time.current, shipped: false, credits_per_hour: 5)
    post project_devlogs_url(@project), params: { devlog: { title: 'Work', content: 'Work', duration_minutes: 20 } }

    existing_ship_ids = Ship.where(project: @project).pluck(:id)
    post ship_admin_project_url(@project)
    assert_redirected_to admin_dashboard_url

    @project.reload
    assert @project.shipped

    ship = Ship.where(project: @project).where.not(id: existing_ship_ids).first
    assert_not_nil ship, "expected a Ship created for project"
    assert_in_delta ((ship.devlogged_seconds.to_f/3600.0) * 5), ship.credits_awarded.to_f, 0.001
    assert_in_delta ship.credits_awarded.to_f, owner.reload.currency.to_f, 0.001
    assert_audit_created(action: 'credit_awarded', project: @project, user: @admin)
  end

  test "approve without supplied rate preserves existing credits_per_hour and awards" do
    sign_in_as(@admin, password: 'password')

    owner = @project.user
    owner.update!(currency: 0)

    @project.update!(status: 'pending', ship_requested_at: Time.current, shipped: false, credits_per_hour: 8)
    post project_devlogs_url(@project), params: { devlog: { title: 'Work', content: 'Work', duration_minutes: 30 } }

    existing_ship_ids = Ship.where(project: @project).pluck(:id)
    post approve_admin_project_url(@project) # no credits_per_hour param
    assert_redirected_to admin_dashboard_url

    @project.reload
    assert_equal 8, @project.credits_per_hour

    ship = Ship.where(project: @project).where.not(id: existing_ship_ids).first
    assert_not_nil ship, "expected a Ship created for project"
    assert_in_delta ((ship.devlogged_seconds.to_f/3600.0) * 8), ship.credits_awarded.to_f, 0.001
    assert_in_delta ship.credits_awarded.to_f, owner.reload.currency.to_f, 0.001
    assert_audit_created(action: 'credit_awarded', project: @project, user: @admin)
  end

  test "approve falls back to total_seconds when there are no post-request devlogs" do
    sign_in_as(@admin, password: 'password')

    owner = @project.user
    owner.update!(currency: 0)

    # project has 12 hours recorded in total_seconds but no devlogs after the request
    @project.update!(status: 'pending', ship_requested_at: Time.current, shipped: false, credits_per_hour: 10, total_seconds: 12.hours.to_i)

    # no post-request devlogs created here
    existing_ship_ids = Ship.where(project: @project).pluck(:id)
    post approve_admin_project_url(@project)
    assert_redirected_to admin_dashboard_url

    @project.reload
    ship = Ship.where(project: @project).where.not(id: existing_ship_ids).first
    assert_not_nil ship, "expected a Ship created for project"

    # 12 hours * 10 credits/hr = 120 credits
    assert_in_delta 120.0, ship.credits_awarded.to_f, 0.001
    assert_in_delta 120.0, owner.reload.currency.to_f, 0.001
    assert_audit_created(action: 'credit_awarded', project: @project, user: @admin)
  end

  test "set_status to shipped without supplied rate preserves existing rate and awards" do
    sign_in_as(@admin, password: 'password')

    owner = @project.user
    owner.update!(currency: 0)

    @project.update!(status: 'pending', ship_requested_at: Time.current, shipped: false, credits_per_hour: 4)
    post project_devlogs_url(@project), params: { devlog: { title: 'Work', content: 'Work', duration_minutes: 15 } }

    existing_ship_ids = Ship.where(project: @project).pluck(:id)
    post set_status_admin_project_url(@project), params: { status: 'shipped' }
    assert_redirected_to admin_dashboard_url

    @project.reload
    assert_equal 'shipped', @project.status
    assert_equal 4, @project.credits_per_hour

    ship = Ship.where(project: @project).where.not(id: existing_ship_ids).first
    assert_not_nil ship, "expected a Ship created for project"
    assert_in_delta ((ship.devlogged_seconds.to_f/3600.0) * 4), ship.credits_awarded.to_f, 0.001
    assert_in_delta ship.credits_awarded.to_f, owner.reload.currency.to_f, 0.001
    assert_audit_created(action: 'credit_awarded', project: @project, user: @admin)
  end
  test "index shows all projects and can change status" do
    sign_in_as(@admin, password: 'password')

    get admin_projects_url
    assert_response :success

    # pick a project and change status via set_status
    project = projects(:one)
    post set_status_admin_project_url(project), params: { status: 'shipped' }
    assert_redirected_to admin_dashboard_url
    assert_equal 'shipped', project.reload.status
  end
end
