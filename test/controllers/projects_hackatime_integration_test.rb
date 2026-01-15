require "test_helper"

class ProjectsHackatimeIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:one)
    @owner.update!(hackatime_api_key: 'key', slack_id: 'slack-1', email: 'owner-hack@example.com')
    sign_in_as(@owner)
  end

  test "creating project with selected hackatime projects updates total_seconds" do
    # Stub HackatimeService to return specific seconds per project
    fake = Object.new
    def fake.get_project_stats(name)
      case name
      when 'A' then 3600
      when 'B' then 1800
      else 0
      end
    end

    # Monkeypatch HackatimeService#get_project_stats instance method to return desired values
    original = HackatimeService.instance_method(:get_project_stats)
    HackatimeService.define_method(:get_project_stats) do |name|
      case name
      when 'A' then 3600
      when 'B' then 1800
      else 0
      end
    end

    begin
      assert_difference('Project.count') do
        post projects_url, params: { project: { name: 'Hacked Project', repository_url: 'x', hackatime_ids: ['A','B'] } }
      end

      p = Project.last
      assert_equal 5400, p.total_seconds
    ensure
      HackatimeService.define_method(:get_project_stats, original)
    end
  end

  test "updating hackatime selection recalculates total_seconds" do
    p = Project.create!(user: @owner, name: 'Initial', repository_url: 'x', hackatime_ids: ['A'])

    # Monkeypatch instance method get_project_stats to return for 'A'
    original = HackatimeService.instance_method(:get_project_stats)
    HackatimeService.define_method(:get_project_stats) do |name|
      name == 'A' ? 3600 : 0
    end

    begin
      p.update_time_from_hackatime!
      assert_equal 3600, p.total_seconds

      # Now request the edit page and ensure the chip shows the formatted time
      get edit_project_url(p)
      assert_response :success
      assert_select '.hackatime-seconds', /1h/ # shows 1 hour for A
    ensure
      HackatimeService.define_method(:get_project_stats, original)
    end

    # Now monkeypatch to return for 'B' when updating
    original2 = HackatimeService.instance_method(:get_project_stats)
    HackatimeService.define_method(:get_project_stats) do |name|
      name == 'B' ? 1800 : 0
    end

    begin
      patch project_url(p), params: { project: { hackatime_ids: ['B'], name: p.name } }
      assert_redirected_to project_url(p)
      assert_equal 1800, p.reload.total_seconds
    ensure
      HackatimeService.define_method(:get_project_stats, original2)
    end
  end
end