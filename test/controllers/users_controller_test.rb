require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "show renders when a ship's project is missing" do
    user = users(:one)

    # create a temporary project and ship, then remove the project reference to simulate missing project
    project = Project.create!(name: 'Temp Project', repository_url: 'http://example.com', user: user)
    ship = Ship.create!(project: project, user: user, shipped_at: Time.current)

    # simulate missing project (e.g., project deleted or data inconsistency)
    ship.update_column(:project_id, nil)

    get user_profile_url(user)
    assert_response :success

    assert_includes response.body, 'Project removed'
  end
end
