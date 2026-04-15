require "test_helper"

class RsvpControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get rsvp_url
    assert_response :success
  end

  test "should get new" do
    get new_rsvp_url
    assert_response :success
  end

  test "guest create stores RSVP with name and slack_id" do
    assert_difference("Rsvp.count", 1) do
      post rsvps_url, params: { rsvp: { name: "Guest User", slack_id: "UGUEST123" } }
    end

    assert_redirected_to rsvp_url
    rsvp = Rsvp.order(:created_at).last
    assert_equal "Guest User", rsvp.name
    assert_equal "UGUEST123", rsvp.slack_id
    assert_nil rsvp.user_id
  end

  test "signed-in create links RSVP to user" do
    sign_in_as users(:admin)

    assert_difference("Rsvp.count", 1) do
      post rsvps_url, params: { rsvp: { name: "Admin User", slack_id: "UADMIN123" } }
    end

    assert_redirected_to rsvp_url
    assert_equal users(:admin).id, Rsvp.order(:created_at).last.user_id
  end

  test "create renders new with errors when fields are missing" do
    assert_no_difference("Rsvp.count") do
      post rsvps_url, params: { rsvp: { name: "", slack_id: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "submit_after_login creates RSVP for signed-in user" do
    sign_in_as users(:admin)

    assert_difference("Rsvp.count", 1) do
      get rsvp_submit_after_login_url
    end

    assert_redirected_to rsvp_url
  end

  test "submit_after_login redirects guests to hackclub login" do
    get rsvp_submit_after_login_url

    assert_response :redirect
    assert_includes response.headers["Location"], "/auth/hackclub"
    assert_includes response.headers["Location"], "origin=%2Frsvp%2Fsubmit_after_login"
  end
end
