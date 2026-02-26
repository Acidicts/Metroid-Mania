require "test_helper"

class Admin::SiteSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
  end

  test "can view and update shop, running, and login restriction settings" do
    get admin_site_settings_url
    assert_response :success

    patch admin_site_settings_url, params: { site_setting: {
      shop: "0",
      running: "0",
      disable_non_admin_logins: "1",
      disable_asset_project: "1",
      weekly_goal_threshold_seconds: "12345"
    } }
    assert_redirected_to admin_site_settings_url
    assert_not SiteSetting.enabled?("shop")
    assert_not SiteSetting.enabled?("running")
    assert SiteSetting.enabled?("disable_non_admin_logins")
    assert SiteSetting.enabled?("disable_asset_project")
    assert_equal "12345", SiteSetting.get("weekly_goal_threshold_seconds")
  ensure
    SiteSetting.set("shop", "true")
    SiteSetting.set("running", "true")
    SiteSetting.set("disable_non_admin_logins", "false")
    SiteSetting.set("disable_asset_project", "false")
  end
end
