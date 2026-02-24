require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    owner = users(:one)
    owner.update!(email: "owner@example.com") unless owner.email.present?
    sign_in_as(owner)
  end

  test "should get index" do
    get projects_url
    assert_response :success
  end

  test "redirects to home when not logged in" do
    # ensure no user is signed in
    delete logout_url rescue nil

    get projects_url
    assert_redirected_to home_path
    # controller sets a :warn flash for this scenario
    assert_match /Please sign in to view projects\./, flash[:warn]
  end

  test "should get new" do
    get new_project_url
    assert_response :success
  end

  test "should create project" do
    assert_difference("Project.count") do
      post projects_url, params: {
        project: {
          hackatime_ids: [ "NewProjectForCreate" ],
          name: @project.name,
          repository_url: @project.repository_url,
          status: @project.status,
          total_seconds: @project.total_seconds,
          user_id: @project.user_id,
          project_tag_id: project_tags(:one).id
        }
      }
    end

    created = Project.last
    assert_redirected_to project_url(created)
    assert_equal "unshipped", created.status
    assert_equal false, created.shipped
    assert_equal project_tags(:one).id, created.project_tag_id
  end

  test "can create project without a tag" do
    assert_difference("Project.count") do
      post projects_url, params: {
        project: {
          hackatime_ids: [ "NewProjectForCreate" ],
          name: "Untitled",
          repository_url: "x",
          status: "unshipped",
          total_seconds: 0,
          user_id: users(:one).id
          # no project_tag_id param
        }
      }
    end

    created = Project.last
    assert_nil created.project_tag_id
  end

  test "should show project" do
    get project_url(@project)
    assert_response :success
  end

  test "owner can see ship comments (admins may post)" do
    # fixture: comments(:ship_one) -> ships(:one) -> projects(:one)
    get project_url(@project)
    assert_response :success
    assert_match /Ship comment/, @response.body
  end

  test "admin can see ship comments" do
    admin = users(:admin)
    admin.update!(role: :admin)
    sign_in_as(admin)

    get project_url(@project)
    assert_response :success
    assert_match /Ship comment/, @response.body
  end

  test "should get edit" do
    get edit_project_url(@project)
    assert_response :success
  end

  test "should update project" do
    # Ensure we're updating an unshipped project so validations about locked hackatime links don't block the update
    @project.ships.destroy_all
    @project.update!(shipped: false, shipped_at: nil)

    new_tag = project_tags(:two)
    patch project_url(@project), params: { project: { name: @project.name, repository_url: @project.repository_url, status: @project.status, total_seconds: @project.total_seconds, user_id: @project.user_id, project_tag_id: new_tag.id } }
    assert_redirected_to project_url(@project)
    assert_equal new_tag.id, @project.reload.project_tag_id
  end

  test "can clear project_tag when updating" do
    @project.ships.destroy_all
    @project.update!(project_tag_id: project_tags(:one).id, shipped: false, shipped_at: nil)
    patch project_url(@project), params: { project: { project_tag_id: nil, name: @project.name } }
    assert_redirected_to project_url(@project)
    assert_nil @project.reload.project_tag_id
  end

  test "can remove hackatime projects by clearing selection" do
    # Use a fresh, never-shipped project so clearing selection is permitted
    owner = users(:one)
    p = Project.create!(user: owner, name: "Clearable", repository_url: "x", hackatime_ids: [ "A", "B" ], total_seconds: 0)

    patch project_url(p), params: { project: { name: p.name } } # no hackatime_ids param
    assert_redirected_to project_url(p)
    assert_empty p.reload.hackatime_ids
  end

  test "should destroy project (soft-delete)" do
    delete project_url(@project)

    assert_redirected_to projects_url

    @project.reload
    assert_not_nil @project.deleted_at
    assert_equal "Deleted Project", @project.name
  end

  test "owner can request ship and admin approves to ship" do
    # Owner creates a devlog (initial work)
    post project_devlogs_url(@project), params: { devlog: { title: "Initial work", content: "Done", duration_minutes: 20 } }

    # Owner requests shipping
    post ship_project_url(@project)
    assert_redirected_to project_url(@project)
    assert_equal "pending", @project.reload.status
    assert_not_nil @project.ship_requested_at

    # Admin approves and marks shipped
    admin = users(:one)
    admin.update!(role: :admin, email: "admin-ship@example.com", password: "password")
    sign_in_as(admin, password: "password")

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
    @project.update!(status: "shipped", shipped: true, shipped_at: Time.current)
    # Create a ship record so computed_status returns 'shipped'
    @project.ships.create!(user: @project.user, shipped_at: Time.current, devlogged_seconds: 1, credits_awarded: 1.0)

    get project_url(@project)
    assert_response :success
    # UI uses a span message and the link text is 'New Devlog' now
    assert_select "span", /Add a devlog to request another ship/
    assert_select "a", "New Devlog"
  end

  test "owner sees minutes-needed message when not enough devlogged minutes" do
    @project.devlogs.destroy_all
    @project.update!(status: "unshipped", shipped: false, shipped_at: nil)
    # Remove any existing ships so computed_status returns 'unshipped'
    @project.ships.destroy_all

    get project_url(@project)
    assert_response :success
    assert_select "div", /You need 15 more minutes/
    assert_select "a", "New Devlog"
  end
end
