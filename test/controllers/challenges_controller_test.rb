require "test_helper"

class ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @challenge = challenges(:one)
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
      post challenges_url, params: { challenge: { active: @challenge.active, description: @challenge.description, end_at: @challenge.end_at, multiplier: @challenge.multiplier, reward_notches: @challenge.reward_notches, start_at: @challenge.start_at, title: @challenge.title } }
    end

    assert_redirected_to challenge_url(Challenge.last)
  end

  test "should show challenge" do
    get challenge_url(@challenge)
    assert_response :success
  end

  test "should get edit" do
    get edit_challenge_url(@challenge)
    assert_response :success
  end

  test "should update challenge" do
    patch challenge_url(@challenge), params: { challenge: { active: @challenge.active, description: @challenge.description, end_at: @challenge.end_at, multiplier: @challenge.multiplier, reward_notches: @challenge.reward_notches, start_at: @challenge.start_at, title: @challenge.title } }
    assert_redirected_to challenge_url(@challenge)
  end

  test "should destroy challenge" do
    assert_difference("Challenge.count", -1) do
      delete challenge_url(@challenge)
    end

    assert_redirected_to challenges_url
  end
end
