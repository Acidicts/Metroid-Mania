require "test_helper"

class HackatimeProjectSyncJobTest < ActiveJob::TestCase
  test "perform updates projects based on HackatimeService" do
    user = users(:one)
    user.update!(slack_id: 'U789')

    p = Project.create!(user: user, name: 'P', repository_url: 'x', hackatime_ids: ['C'], total_seconds: 0)

    original = HackatimeService.instance_method(:get_projects)
    HackatimeService.define_method(:get_projects) do |start_date: HackatimeService::START_DATE, end_date: nil|
      { 'C' => 7200 }
    end

    begin
      HackatimeProjectSyncJob.perform_now(user.id)
      assert_equal 7200, p.reload.total_seconds
    ensure
      HackatimeService.define_method(:get_projects, original)
    end
  end
end
