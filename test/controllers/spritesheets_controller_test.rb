require "test_helper"

class SpritesheetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @item = assets_items(:one)
    SiteSetting.set("disable_asset_project", "false")
  end

  teardown do
    SiteSetting.set("disable_asset_project", "true")
  end

  test "should get new" do
    get new_assets_item_spritesheet_path(@item)
    assert_response :success
  end

  test "should show spritesheet" do
    sheet = @item.spritesheets.create!(url: "https://example.com/sheet.png", name: "Walk")
    get assets_item_spritesheet_path(@item, sheet)
    assert_response :success
  end

  test "should create spritesheet" do
    post assets_item_spritesheets_path(@item), params: { spritesheet: { name: "Idle", url: "https://example.com/idle.png" } }
    assert_response :redirect
  end

  test "should update spritesheet" do
    sheet = @item.spritesheets.create!(url: "https://example.com/sheet.png", name: "Walk")
    patch assets_item_spritesheet_path(@item, sheet), params: { spritesheet: { name: "Run" } }
    assert_response :redirect
  end

  test "should destroy spritesheet" do
    sheet = @item.spritesheets.create!(url: "https://example.com/sheet.png", name: "Walk")
    delete assets_item_spritesheet_path(@item, sheet)
    assert_response :redirect
  end
end
