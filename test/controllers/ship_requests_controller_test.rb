require "test_helper"

class ShipRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    sign_in_as(@owner)
  end

  test "new shows checklist with checked items when appropriate" do
    p = Project.create!(user: @owner, name: "Checklist Project", repository_url: "https://example.com/repo.git", readme_url: nil, total_seconds: 0)

    get new_project_ship_request_path(p)
    assert_response :success

    # 'No existing pending ship request' should be checked (no pending requests)
    assert_select ".checklist_ship .task-list-item--checked", /No existing pending ship request/

    # 'Project is clonable' should be checked for the .git or http(s) repo URL
    assert_select ".checklist_ship .task-list-item--checked", /Project is clonable/
  end

  test "show allows project owner and admins, denies others" do
    project = Project.create!(user: @owner, name: "Show Project", repository_url: "https://example.com/repo.git", readme_url: nil, total_seconds: 0)
    req = project.ship_requests.create!(user: @owner, requested_at: Time.current, devlogged_seconds: 900, status: "pending")

    # owner can view
    get project_ship_request_path(project, req)
    assert_response :success

    # non-owner non-admin cannot view
    other = users(:two)
    sign_in_as(other)
    get project_ship_request_path(project, req)
    assert_redirected_to project_path(project)

    # admin can view
    admin = users(:one)
    admin.update!(role: :admin)
    sign_in_as(admin)
    get project_ship_request_path(project, req)
    assert_response :success
  end
end
