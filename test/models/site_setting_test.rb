require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  test "enabled? returns default when setting missing" do
    assert_equal true, SiteSetting.enabled?("nonexistent_key")
    assert_equal false, SiteSetting.enabled?("nonexistent_key", default: false)
  end

  test "enabled? respects stored values" do
    SiteSetting.set("test_enabled", "true")
    assert_equal true, SiteSetting.enabled?("test_enabled")
  end

  test "enabled? returns false for falsy values" do
    SiteSetting.set("test_disabled", "false")
    assert_equal false, SiteSetting.enabled?("test_disabled")
  end

  test "self.get returns default when missing" do
    assert_nil SiteSetting.get("missing_key")
    assert_equal "default", SiteSetting.get("missing_key", "default")
  end

  test "self.get returns stored value" do
    SiteSetting.set("my_key", "my_value")
    assert_equal "my_value", SiteSetting.get("my_key")
  end

  test "self.set creates or updates setting" do
    SiteSetting.set("new_key", "new_value")
    assert_equal "new_value", SiteSetting.get("new_key")

    SiteSetting.set("new_key", "updated")
    assert_equal "updated", SiteSetting.get("new_key")
  end

  test "validates key presence" do
    s = SiteSetting.new(key: nil)
    assert_not s.valid?
    assert_includes s.errors[:key], "can't be blank"
  end

  test "validates key uniqueness" do
    SiteSetting.create!(key: "unique_key", value: "val1")
    s = SiteSetting.new(key: "unique_key", value: "val2")
    assert_not s.valid?
    assert_includes s.errors[:key], "has already been taken"
  end
end
