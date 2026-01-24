require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    owner = users(:one)
    owner.update!(email: 'owner@example.com') unless owner.email.present?
    sign_in_as(owner)
  end

  test "should get index" do
    get projects_url
    assert_response :success
  end

  test "should get new" do
    get new_project_url
    assert_response :success
  end

  test "should create project" do
    assert_difference("Project.count") do
      post projects_url, params: { project: { hackatime_ids: ['NewProjectForCreate'], name: @project.name, repository_url: @project.repository_url, status: @project.status, total_seconds: @project.total_seconds, user_id: @project.user_id } }
    end

    assert_redirected_to project_url(Project.last)
    assert_equal 'unshipped', Project.last.status
    assert_equal false, Project.last.shipped
  end

  test "should show project" do
    get project_url(@project)
    assert_response :success
  end

  test "should get edit" do
    get edit_project_url(@project)
    assert_response :success
  end

  test "should update project" do
    patch project_url(@project), params: { project: { name: @project.name, repository_url: @project.repository_url, status: @project.status, total_seconds: @project.total_seconds, user_id: @project.user_id } }
    assert_redirected_to project_url(@project)
  end

  test "can remove hackatime projects by clearing selection" do
    p = projects(:one)
    p.update!(hackatime_ids: ['A','B'])

    patch project_url(p), params: { project: { name: p.name } } # no hackatime_ids param
    assert_redirected_to project_url(p)
    assert_empty p.reload.hackatime_ids
  end

  test "should destroy project" do
    assert_difference("Project.count", -1) do
      delete project_url(@project)
    end

    assert_redirected_to projects_url
  end

  test "owner can request ship and admin approves to ship" do
    # Owner creates a devlog (initial work)
    post project_devlogs_url(@project), params: { devlog: { title: 'Initial work', content: 'Done', duration_minutes: 20 } }

    # Owner requests shipping
    post ship_project_url(@project)
    assert_redirected_to project_url(@project)
    assert_equal 'pending', @project.reload.status
    assert_not_nil @project.ship_requested_at

    # Admin approves and marks shipped
    admin = users(:one)
    admin.update!(role: :admin, email: 'admin-ship@example.com', password: 'password')
    sign_in_as(admin, password: 'password')

    post approve_admin_project_url(@project), params: { credits_per_hour: 10 }
    assert_redirected_to admin_dashboard_url
    assert @project.reload.shipped
    assert_equal 10, @project.reload.credits_per_hour
  end

  test "non-owner cannot ship project" do
    other = users(:two)
    sign_in_as(other)

    post ship_project_url(@project)
    assert_redirected_to project_url(@project)
    assert_not @project.reload.shipped
  end

  test "owner sees explanation when missing post-approval devlog" do
    # Project is shipped, but there's no post-ship devlog
    @project.update!(status: 'shipped', shipped: true, shipped_at: Time.current)
    # Create a ship record so computed_status returns 'shipped'
    @project.ships.create!(user: @project.user, shipped_at: Time.current, devlogged_seconds: 1, credits_awarded: 1.0)

    get project_url(@project)
    assert_response :success
    # UI uses a span message and the link text is 'New Devlog' now
    assert_select 'span', /Add a devlog to request another ship/ 
    assert_select 'a', 'New Devlog'
  end

  test "owner sees minutes-needed message when not enough devlogged minutes" do
    @project.devlogs.destroy_all
    @project.update!(status: 'unshipped', shipped: false, shipped_at: nil)
    # Remove any existing ships so computed_status returns 'unshipped'
    @project.ships.destroy_all

    get project_url(@project)
    assert_response :success
    assert_select 'div', /You need 15 more minutes/ 
    assert_select 'a', 'New Devlog'
  end
end
