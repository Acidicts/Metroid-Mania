require "test_helper"

class AchievementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @achievement = achievements(:one)
    # log in as admin by default so we can exercise create/update/destroy without redirects
    sign_in_as users(:admin)
  end

  test "should get index" do
    get achievements_url
    assert_response :success
  end

  test "index page renders earned message when current_user has achievement" do
    # sign in as regular user
    user = users(:one)
    sign_in_as user

    # ensure achievement one is marked as earned
    @achievement.user_achievements.create!(user: user, unlocked_at: Time.current)

    get achievements_url
    assert_response :success
    assert_select "#achievement_#{@achievement.id}" do
      assert_select "div", text: /✓ Earned/ 
    end
  end

  test "should get new" do
    get new_achievement_url
    assert_response :success
  end

  test "should create achievement" do
    assert_difference("Achievement.count") do
      post achievements_url, params: { achievement: { description: @achievement.description, title: @achievement.title, requirement_type: @achievement.requirement_type, requirement_value: @achievement.requirement_value } }
    end

    assert_redirected_to achievement_url(Achievement.last)
  end

  test "should show achievement" do
    get achievement_url(@achievement)
    assert_response :success
  end

  test "should get edit" do
    get edit_achievement_url(@achievement)
    assert_response :success
  end

  test "should update achievement" do
    patch achievement_url(@achievement), params: { achievement: { description: @achievement.description, title: @achievement.title, requirement_type: @achievement.requirement_type, requirement_value: @achievement.requirement_value } }
    assert_redirected_to achievement_url(@achievement)
  end

  test "should destroy achievement" do
    assert_difference("Achievement.count", -1) do
      delete achievement_url(@achievement)
    end

    assert_redirected_to achievements_url
  end
end
