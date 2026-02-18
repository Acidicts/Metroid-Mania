require "test_helper"

class Admin::SiteSettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in_as(@admin)
  end

  test "can view and update shop setting" do
    get admin_site_settings_url
    assert_response :success

    patch admin_site_settings_url, params: { site_setting: { enabled: "0" } }
    assert_redirected_to admin_site_settings_url
    assert_not SiteSetting.enabled?("shop")
  ensure
    SiteSetting.set("shop", "true")
  end
end
