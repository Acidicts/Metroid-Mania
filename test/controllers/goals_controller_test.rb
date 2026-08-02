require "test_helper"

class GoalsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get goals_url
    assert_response :success
  end

  test "index shows progress bar with current totals" do
    # configure a low threshold so we can easily check percentage
    SiteSetting.set("weekly_goal_threshold_seconds", "3600")
    travel_to Time.zone.now.beginning_of_week + 2.hours do
      user = users(:one)
      Devlog.create!(user: user, project: projects(:one), title: "foo", content: "bar", log_date: Date.today, duration_seconds: 1800)

      get goals_url
      assert_response :success
      # verify percentage text and human durations appear in the output
      assert_match /50%/, response.body
      assert_match /0h\s*30m.*still needed this week/, response.body.squish
      assert_match /1h/, response.body.squish
    end
  ensure
    SiteSetting.set("weekly_goal_threshold_seconds", "")
  end

  test "should get edit" do
    # edit requires an id; use a placeholder value because controller doesn't
    # actually depend on a real record yet.
    get edit_goal_url(1)
    assert_response :success
  end

  test "should get new" do
    get new_goal_url
    assert_response :success
  end

  test "non-admin cannot trigger award actions" do
    sign_in_as(users(:one))
    post award_goals_url
    assert_redirected_to root_path
    post force_award_goals_url
    assert_redirected_to root_path
  end

  test "admin sees buttons on index" do
    # dev login works fine for test environment and avoids relying on the
    # password fixture.  the admin role is already set in fixtures.
    sign_in_as(users(:admin))
    get goals_url
    assert_response :success
    assert_match /Issue weekly goal prize/, response.body
    assert_match /Force issue prize/, response.body
  end

  test "regular user does not see admin buttons" do
    sign_in_as(users(:one))
    get goals_url
    assert_response :success
    assert_no_match /Issue weekly goal prize/, response.body
    assert_no_match /Force issue prize/, response.body
  end

  test "admin can award prize when threshold met" do
    sign_in_as(users(:admin))

    # instead of exercising the full service logic (which runs automatically
    # via devlog callbacks and proved tricky in integration tests), stub the
    # service to verify the controller correctly handles the return value and
    # redirects appropriately.
    fake = Order.new(id: 123)
    # temporarily override the service method so we don't rely on its
    # internal logic in this controller test.
    orig = WeeklyGoalService.method(:check_and_award!)
    WeeklyGoalService.define_singleton_method(:check_and_award!) { fake }
    begin
      post award_goals_url
      assert_redirected_to goals_url
      follow_redirect!
      assert_match(/prize issued/i, response.body)
    ensure
      WeeklyGoalService.define_singleton_method(:check_and_award!, orig)
    end
  end

  test "admin can force award prize regardless of threshold" do
    sign_in_as(users(:admin))
    SiteSetting.set("weekly_goal_threshold_seconds", "1000000")
    travel_to Time.zone.now.beginning_of_week + 1.hour do
      user = users(:one)
      # small devlog so threshold not reached (use minimum permitted duration)
      Devlog.create!(user: user, project: projects(:one), title: "x", content: "y", log_date: Date.today, duration_seconds: 60)
      post force_award_goals_url
    end
    assert_redirected_to goals_url
    follow_redirect!
    assert_match(/forcibly issued/i, response.body)
    assert Order.where(product: WeeklyGoalService.prize_product).exists?
  ensure
    SiteSetting.set("weekly_goal_threshold_seconds", "")
    SiteSetting.set("weekly_goal_last_awarded_at", "")
    prize = WeeklyGoalService.prize_product
    orders = Order.where(product: prize)
    CharmSlot.where(order_id: orders).update_all(order_id: nil)
    orders.delete_all
  end
end
