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
end
