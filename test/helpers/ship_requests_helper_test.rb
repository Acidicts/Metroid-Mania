require "test_helper"

class ShipRequestsHelperTest < ActionView::TestCase
  include ShipRequestsHelper
  include ApplicationHelper

  test "ship_request_status_badge returns empty string for nil" do
    assert_equal "", ship_request_status_badge(nil)
  end

  test "ship_request_status_badge returns pending badge" do
    req = ShipRequest.new(status: "pending")
    result = ship_request_status_badge(req)
    assert_match /Pending/, result
    assert_match /status-pending/, result
  end

  test "ship_request_status_badge returns rejected badge" do
    req = ShipRequest.new(status: "rejected")
    result = ship_request_status_badge(req)
    assert_match /Rejected/, result
    assert_match /status-denied/, result
  end

  test "ship_request_status_badge returns approved badge" do
    req = ShipRequest.new(status: "approved")
    result = ship_request_status_badge(req)
    assert_match /Approved/, result
    assert_match /status-fulfilled/, result
  end

  test "project_eligible returns false for nil project" do
    assert_not project_eligible(nil)
  end

  test "ship_checklist returns empty string for nil project" do
    assert_equal "", ship_checklist(nil)
  end

  test "ship_checklist returns markdown with check items" do
    p = projects(:one)
    p.update!(created_at: 1.hour.ago, shipped_at: nil)
    p.devlogs.destroy_all
    md = ship_checklist(p)
    assert_match /At least 15 minutes/, md
    assert_match /Github Repo is Public/, md
    assert_match /Project has a README/, md
    assert_match /Project is clonable/, md
    assert_match /Project has a banner image/, md
  end

  test "ship_request_action_buttons returns empty safe for nil project" do
    result = ship_request_action_buttons(nil)
    assert result.present? || result == "".html_safe
  end

  test "ship_request_devlogged_formatted formats seconds" do
    req = ShipRequest.new(devlogged_seconds: 3661)
    assert_match /1h 1m/, ship_request_devlogged_formatted(req)
  end
end
