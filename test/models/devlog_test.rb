require "test_helper"

class DevlogTest < ActiveSupport::TestCase
  test "duration_seconds_total returns duration_seconds when present" do
    d = Devlog.new(duration_seconds: 120)
    assert_equal 120, d.duration_seconds_total
  end

  test "duration_seconds_total falls back to duration_minutes" do
    d = Devlog.new(duration_seconds: nil, duration_minutes: 5)
    assert_equal 300, d.duration_seconds_total
  end

  test "duration_seconds_total returns nil when both nil" do
    d = Devlog.new(duration_seconds: nil, duration_minutes: nil)
    assert_nil d.duration_seconds_total
  end

  test "owner_minimum_duration requires at least 1 minute for non-system devlogs" do
    d = Devlog.new(duration_seconds: 30, user: users(:one), project: projects(:one), log_date: Date.current)
    assert_not d.valid?
    assert d.errors[:duration_minutes].any?
  end

  test "owner_minimum_duration allows system devlogs with 0 seconds" do
    req = ShipRequest.create!(user: users(:one), project: projects(:one), status: "pending", devlogged_seconds: 0, requested_at: Time.current)
    d = Devlog.new(duration_seconds: 0, ship_request: req, project: projects(:one), log_date: Date.current)
    assert d.valid?
  end

  test "editable_by? returns true for admin" do
    d = Devlog.new(user: users(:one))
    assert d.editable_by?(users(:admin))
  end

  test "editable_by? returns true for owner" do
    user = users(:one)
    d = Devlog.new(user: user)
    assert d.editable_by?(user)
  end

  test "editable_by? returns false for non-owner" do
    d = Devlog.new(user: users(:one))
    assert_not d.editable_by?(users(:two))
  end

  test "editable_by? returns false for nil user" do
    d = Devlog.new(user: users(:one))
    assert_not d.editable_by?(nil)
  end

  test "editable_by? returns false for system-generated devlog" do
    req = ShipRequest.create!(user: users(:one), project: projects(:one), status: "pending", devlogged_seconds: 3600, requested_at: Time.current)
    d = Devlog.create!(user: users(:one), project: projects(:one), duration_seconds: 3600, log_date: Date.current, ship_request: req)
    assert_not d.editable_by?(users(:one))
  end

  test "self.total_duration_seconds sums within date range" do
    user = users(:one)
    project = projects(:one)
    project.devlogs.where(user: user).destroy_all
    project.devlogs.create!(user: user, duration_seconds: 3600, log_date: Date.today)
    project.devlogs.create!(user: user, duration_seconds: 1800, log_date: Date.today)

    range = Date.today..Date.today
    assert_equal 5400, Devlog.total_duration_seconds(range)
  end

  test "self.total_duration_seconds excludes ship request devlogs" do
    user = users(:one)
    project = projects(:one)
    project.devlogs.where(user: user).destroy_all
    req = ShipRequest.create!(user: user, project: project, status: "pending", devlogged_seconds: 3600, requested_at: Time.current)
    project.devlogs.create!(user: user, duration_seconds: 3600, log_date: Date.current)
    project.devlogs.create!(duration_seconds: 7200, log_date: Date.current, ship_request: req)

    range = Date.current..Date.current
    assert_equal 3600, Devlog.total_duration_seconds(range)
  end

  test "ensure_duration_seconds converts minutes to seconds" do
    d = Devlog.new(duration_minutes: 5, duration_seconds: nil)
    d.valid?
    assert_equal 300, d.duration_seconds
  end

  test "belongs_to project" do
    d = Devlog.new(project: projects(:one))
    assert_equal projects(:one), d.project
  end

  test "belongs_to user optionally" do
    d = Devlog.new(project: projects(:one), duration_seconds: 60, log_date: Date.current)
    assert d.valid?
  end

  test "has_many comments" do
    d = devlogs(:one)
    comment = Comment.create!(user: users(:one), message: "test", commentable: d)
    assert_includes d.comments, comment
  end
end
