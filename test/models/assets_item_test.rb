require "test_helper"

class AssetsItemTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    item = AssetsItem.new(title: "Sword", description: "A sword", media_type: "sprite", user: users(:one), assets_project: assets_projects(:one))
    assert item.valid?
  end

  test "compatibility project_id returns assets_project_id" do
    item = assets_items(:one)
    assert_equal item.assets_project_id, item.project_id
  end

  test "compatibility project_id= sets assets_project_id" do
    item = AssetsItem.new
    item.project_id = 42
    assert_equal 42, item.assets_project_id
  end

  test "compatibility project returns assets_project" do
    item = assets_items(:one)
    assert_equal item.assets_project, item.project
  end

  test "compatibility project= sets assets_project" do
    item = AssetsItem.new
    item.project = assets_projects(:two)
    assert_equal assets_projects(:two), item.assets_project
  end

  test "validates spritesheet_url format" do
    item = AssetsItem.new(spritesheet_url: "not-a-url")
    assert_not item.valid?
    assert item.errors[:spritesheet_url].any?
  end

  test "allows blank spritesheet_url" do
    item = AssetsItem.new(title: "Test", description: "Desc", media_type: "sprite", user: users(:one), assets_project: assets_projects(:one), spritesheet_url: "")
    assert item.valid?
  end

  test "spritesheet_url? returns true when present" do
    item = AssetsItem.new(spritesheet_url: "https://example.com/sheet.png")
    assert_predicate item, :spritesheet_url?
  end

  test "spritesheet_url? returns false when blank" do
    item = AssetsItem.new(spritesheet_url: nil)
    assert_not item.spritesheet_url?
  end

  test "has_spritesheets? returns true when spritesheet_url present" do
    item = AssetsItem.new(spritesheet_url: "https://example.com/sheet.png")
    assert item.has_spritesheets?
  end

  test "has_spritesheets? returns true when spritesheets association has records" do
    item = assets_items(:one)
    item.spritesheets.create!(url: "https://example.com/s.png", name: "Idle")
    assert item.has_spritesheets?
  end

  test "has_spritesheets? returns false when nothing present" do
    item = AssetsItem.new
    assert_not item.has_spritesheets?
  end

  test "belongs_to assets_project" do
    item = assets_items(:one)
    assert_equal assets_projects(:one), item.assets_project
  end

  test "belongs_to user" do
    item = assets_items(:one)
    assert_equal users(:one), item.user
  end

  test "has_many spritesheets" do
    item = assets_items(:one)
    sheet = item.spritesheets.create!(url: "https://example.com/s.png", name: "Idle")
    assert_includes item.spritesheets, sheet
  end
end
