require "test_helper"

class UserHackatimeProjectsSyncTest < ActiveSupport::TestCase
  test "sync_hackatime_projects! updates owned projects' totals" do
    user = users(:one)
    user.update!(slack_id: 'U123')

    p1 = Project.create!(user: user, name: 'P1', repository_url: 'x', hackatime_ids: ['A_sync'], total_seconds: 0)
    p2 = Project.create!(user: user, name: 'P2', repository_url: 'x', hackatime_ids: ['B_sync'], total_seconds: 0)
    other = Project.create!(user: users(:two), name: 'Other', repository_url: 'x', hackatime_ids: ['A_other'], total_seconds: 0)

    original = HackatimeService.instance_method(:get_projects)
    HackatimeService.define_method(:get_projects) do |start_date: HackatimeService::START_DATE, end_date: nil|
      { 'A_sync' => 3600, 'B_sync' => 1800 }
    end

    begin
      user.sync_hackatime_projects!

      assert_equal 3600, p1.reload.total_seconds
      assert_equal 1800, p2.reload.total_seconds
      # ensure we don't update other users' projects
      assert_equal 0, other.reload.total_seconds
    ensure
      HackatimeService.define_method(:get_projects, original)
    end
  end

  test "sync_hackatime_projects! leaves totals unchanged when stats empty" do
    user = users(:one)
    user.update!(slack_id: 'U456')

    p = Project.create!(user: user, name: 'P', repository_url: 'x', hackatime_ids: ['X'], total_seconds: 1234)

    original = HackatimeService.instance_method(:get_projects)
    HackatimeService.define_method(:get_projects) do |start_date: HackatimeService::START_DATE, end_date: nil|
      {}
    end

    begin
      user.sync_hackatime_projects!
      assert_equal 1234, p.reload.total_seconds
    ensure
      HackatimeService.define_method(:get_projects, original)
    end
  end
end
