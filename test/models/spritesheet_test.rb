require "test_helper"

class SpritesheetTest < ActiveSupport::TestCase
  test "valid with url and name" do
    item = assets_items(:one)
    sheet = Spritesheet.new(assets_item: item, url: "https://example.com/sheet.png", name: "Walk")
    assert sheet.valid?
  end

  test "validates url presence" do
    sheet = Spritesheet.new(assets_item: assets_items(:one), name: "Walk")
    assert_not sheet.valid?
    assert_includes sheet.errors[:url], "can't be blank"
  end

  test "validates url format" do
    sheet = Spritesheet.new(assets_item: assets_items(:one), url: "not-a-url", name: "Walk")
    assert_not sheet.valid?
    assert sheet.errors[:url].any?
  end

  test "validates name presence" do
    sheet = Spritesheet.new(assets_item: assets_items(:one), url: "https://example.com/sheet.png")
    assert_not sheet.valid?
    assert_includes sheet.errors[:name], "can't be blank"
  end

  test "url? returns true when url present" do
    sheet = Spritesheet.new(url: "https://example.com/sheet.png")
    assert_predicate sheet, :url?
  end

  test "url? returns false when url blank" do
    sheet = Spritesheet.new(url: nil)
    assert_not sheet.url?
  end

  test "belongs_to assets_item" do
    item = assets_items(:one)
    sheet = Spritesheet.new(assets_item: item)
    assert_equal item, sheet.assets_item
  end
end
