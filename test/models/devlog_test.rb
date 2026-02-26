require "test_helper"

class DevlogTest < ActiveSupport::TestCase
  test "duration_seconds_total picks duration_seconds when present" do
    d = Devlog.new(duration_seconds: 120, duration_minutes: 5)
    assert_equal 120, d.duration_seconds_total
  end

  test "duration_seconds_total falls back to duration_minutes and converts to seconds" do
    d = Devlog.new(duration_seconds: nil, duration_minutes: 2)
    assert_equal 120, d.duration_seconds_total
  end

  test "duration_seconds_total returns nil when neither field is set" do
    d = Devlog.new
    assert_nil d.duration_seconds_total
  end

  test "owner_minimum_duration validation requires at least 1 minute for non-system devlogs" do
    # supply the bare minimum attributes to satisfy other validations
    d = Devlog.new(
      duration_seconds: 30,
      project: projects(:one),
      user: users(:one),
      title: "Test",
      content: "Test",
      log_date: Date.today
    )

    assert_not d.valid?
    assert_includes d.errors[:duration_minutes], "must be at least 1 minute"

    # setting to exact minimum should clear the error
    d.duration_seconds = 60
    assert d.valid?
  end

  test "editable_by? is publicly callable and obeys rules" do
    project = projects(:one)
    owner = users(:one)
    other = users(:two)
    admin_user = User.new(role: :admin)
    sup = User.new(role: :superadmin)

    devlog = Devlog.new(
      project: project,
      user: owner,
      title: "x",
      content: "y",
      log_date: Date.today,
      duration_minutes: 10
    )

    assert_not devlog.editable_by?(nil)
    assert devlog.editable_by?(owner)
    assert_not devlog.editable_by?(other)
    assert devlog.editable_by?(admin_user)
    assert devlog.editable_by?(sup)

    # system-generated entry (ship_request) should be non-editable by normal users
    devlog.ship_request = ShipRequest.new
    assert_not devlog.editable_by?(owner)
    assert devlog.editable_by?(admin_user)
  end

  test "check_weekly_goal delegates to WeeklyGoalService" do
    devlog = Devlog.new(project: projects(:one), user: users(:one))
    called = false
    orig = WeeklyGoalService.method(:check_and_award!)
    WeeklyGoalService.define_singleton_method(:check_and_award!) { called = true }
    begin
      devlog.send(:check_weekly_goal)
    ensure
      WeeklyGoalService.define_singleton_method(:check_and_award!, orig)
    end
    assert called, "Expected check_weekly_goal to delegate to WeeklyGoalService.check_and_award!"
  end
end
