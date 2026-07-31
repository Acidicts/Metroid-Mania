require "test_helper"

class ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:admin))
  end

  test "should get index" do
    get challenges_url
    assert_response :success
  end

  test "should get new" do
    get new_challenge_url
    assert_response :success
  end

  test "should create challenge" do
    assert_difference("Challenge.count") do
      post challenges_url, params: { challenge: { title: "Speed Week", start_at: 1.day.ago, end_at: 1.day.from_now, multiplier: 2.0, reward_notches: 5 } }
    end
    assert_redirected_to challenge_url(Challenge.last)
  end

  test "should show challenge" do
    challenge = Challenge.create!(title: "Test", start_at: 1.day.ago, end_at: 1.day.from_now, multiplier: 1.5, reward_notches: 0)
    get challenge_url(challenge)
    assert_response :success
  end

  test "should get edit" do
    challenge = Challenge.create!(title: "Test", start_at: 1.day.ago, end_at: 1.day.from_now, multiplier: 1.5, reward_notches: 0)
    get edit_challenge_url(challenge)
    assert_response :success
  end

  test "should update challenge" do
    challenge = Challenge.create!(title: "Test", start_at: 1.day.ago, end_at: 1.day.from_now, multiplier: 1.5, reward_notches: 0)
    patch challenge_url(challenge), params: { challenge: { title: "Updated" } }
    assert_redirected_to challenge_url(challenge)
  end

  test "should destroy challenge" do
    challenge = Challenge.create!(title: "Test", start_at: 1.day.ago, end_at: 1.day.from_now, multiplier: 1.5, reward_notches: 0)
    assert_difference("Challenge.count", -1) do
      delete challenge_url(challenge)
    end
    assert_redirected_to challenges_url
  end

  test "non-admin cannot create challenge" do
    sign_in_as(users(:one))
    assert_no_difference("Challenge.count") do
      post challenges_url, params: { challenge: { title: "Fail" } }
    end
  end
end
