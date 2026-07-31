require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should get index when logged in" do
    get dashboard_url
    assert_response :success
  end

  test "index loads without error when ORG_SLACK_IDS not defined" do
    get dashboard_url
    assert_response :success
  end
end
