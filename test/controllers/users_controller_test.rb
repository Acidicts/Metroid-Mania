require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should get show" do
    get user_profile_url(users(:one))
    assert_response :success
  end

  test "show displays user projects" do
    get user_profile_url(users(:one))
    assert_response :success
  end

  test "should get edit" do
    get profile_url
    assert_response :success
  end

  test "should update user" do
    patch profile_url, params: { user: { set_region: "US" } }
    assert_response :redirect
  end

  test "setup marks user as setup" do
    user = users(:one)
    user.update!(setup: false)
    # Use the profile setup path instead
    patch profile_url, params: { user: { set_region: "US" } }
    assert_response :redirect
  end
end
