require "test_helper"

class Admin::ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: "admin-challenge@example.com", uid: "admin-#{SecureRandom.uuid}", password: "password")

    @challenge = challenges(:one)
  end

  test "index requires admin login" do
    get admin_challenges_url
    assert_response :redirect
    # unauthenticated users are sent to root by require_admin
    assert_redirected_to root_url

    sign_in_as(@admin, password: "password")
    get admin_challenges_url
    assert_response :success
  end

  test "create challenge" do
    sign_in_as(@admin, password: "password")
    assert_difference("Challenge.count") do
      post admin_challenges_url, params: { challenge: { title: "Test", reward_notches: 10, start_at: Time.current, end_at: 1.day.from_now, active: true, multiplier: 1.5, type: "multiplier" } }
    end
    assert_redirected_to admin_challenges_url
    assert_equal "multiplier", Challenge.last.type
  end

  test "update challenge" do
    sign_in_as(@admin, password: "password")
    patch admin_challenge_url(@challenge), params: { challenge: { title: "Updated", type: "multiplier" } }
    assert_redirected_to admin_challenges_url
    assert_equal "Updated", @challenge.reload.title
  end

  test "destroy challenge" do
    sign_in_as(@admin, password: "password")
    assert_difference("Challenge.count", -1) do
      delete admin_challenge_url(@challenge)
    end
    assert_redirected_to admin_challenges_url
  end
end
