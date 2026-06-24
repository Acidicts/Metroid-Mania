require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "show renders when a ship's project is missing" do
    user = users(:one)
    user.update!(role: :admin, email: "admin-user-show@example.com", password: "password")
    sign_in_as(user, password: "password")
    user = users(:one)

    # create a temporary project and ship, then soft-delete the project so
    # the association still exists but is marked removed.
    project = Project.create!(name: 'Temp Project', repository_url: 'http://example.com', user: user)
    Ship.create!(project: project, user: user, shipped_at: Time.current)

    project.update!(deleted_at: Time.current)

    get user_profile_url(user)
    assert_response :success
    assert_includes response.body, 'Project removed'
  end
end
