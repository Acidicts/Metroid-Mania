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

  test "add then save then remove hackatime chip before any ship" do
    p = Project.create!(user: @owner, name: 'AddThenRemoveUI', repository_url: 'x', total_seconds: 3600)

    # Prevent external calls when the controller refreshes total_seconds
    original = HackatimeService.instance_method(:get_project_stats)
    HackatimeService.define_method(:get_project_stats) do |_name|
      0
    end

    begin
      # Add a hackatime chip and save
      patch project_url(p), params: { project: { hackatime_ids: ['NEW'], name: p.name } }
      assert_redirected_to project_url(p)
      assert_equal ['NEW'], p.reload.hackatime_ids.map(&:to_s)

      # Edit page should show the removable button (not locked)
      get edit_project_url(p)
      assert_response :success
      assert_select '#hackatime-selected .hackatime-chip' do
        assert_select 'button.hackatime-remove--locked[disabled]', 0
        assert_select 'button.hackatime-remove', 1
      end

      # Now remove the chip and save — send no hackatime_ids param (controller treats missing key as empty array)
      patch project_url(p), params: { project: { name: p.name } }
      assert_redirected_to project_url(p)
      assert_empty p.reload.hackatime_ids
    ensure
      HackatimeService.define_method(:get_project_stats, original)
    end
  end

  test "edit form locks removal of hackatime chips if project was shipped using hackatime time" do
    p = Project.create!(user: @owner, name: 'Locked Edit', repository_url: 'x', hackatime_ids: ['A'], total_seconds: 3600)
    # Ship using project's total_seconds (Hackatime-derived usage)
    p.ship_and_award_credits!(admin_user: @owner, rate: 1, devlogged_seconds: 0, shipped_at: Time.current)

    get edit_project_url(p)
    assert_response :success
    assert_select '#hackatime-selected .hackatime-chip' do
      assert_select 'button.hackatime-remove--locked[disabled]', 1
    end
  end

  test "edit form locks removal of hackatime chips after any ship (even when ship used devlogs)" do
    p = Project.create!(user: @owner, name: 'Locked Edit 2', repository_url: 'x', hackatime_ids: ['B'], total_seconds: 3600)
    d = p.devlogs.create!(title: 'Work', content: 'x', duration_minutes: 60, log_date: Date.today, user: @owner)
    p.ship_and_award_credits!(admin_user: @owner, rate: 1, devlogged_seconds: d.duration_seconds, shipped_at: Time.current)

    get edit_project_url(p)
    assert_response :success
    assert_select '#hackatime-selected .hackatime-chip' do
      assert_select 'button.hackatime-remove--locked[disabled]', 1
    end
  end

  test "edit form allows removal of hackatime chips added after last ship" do
    p = Project.create!(user: @owner, name: 'PostShipUI', repository_url: 'x', total_seconds: 3600)

    # Ship first (no hackatime linked at ship time)
    p.ship_and_award_credits!(admin_user: @owner, rate: 1, devlogged_seconds: p.total_seconds, shipped_at: Time.current)

    # Add a hackatime id after the ship — should be removable in the UI
    p.update!(hackatime_ids: ['C'])

    get edit_project_url(p)
    assert_response :success
    assert_select '#hackatime-selected .hackatime-chip' do
      assert_select 'button.hackatime-remove--locked[disabled]', 0
      assert_select 'button.hackatime-remove', 1
    end
  end
end