require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  setup do
    SiteSetting.where(key: "shop").delete_all
  end

  test "enabled? returns default when missing" do
    assert SiteSetting.enabled?("shop", default: true)
    assert_not SiteSetting.enabled?("shop", default: false)
  end

  test "enabled? respects stored values" do
    SiteSetting.set("shop", "false")
    assert_not SiteSetting.enabled?("shop")
    SiteSetting.set("shop", "true")
    assert SiteSetting.enabled?("shop")
  end
end
