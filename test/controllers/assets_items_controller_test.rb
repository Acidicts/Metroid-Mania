require "test_helper"

class AssetsItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @assets_item = assets_items(:one)
    sign_in_as(users(:one))
  end

  test "should get index" do
    get assets_items_url
    assert_redirected_to projects_url
  end

  test "should get new" do
    get new_assets_item_url
    assert_response :success
  end

  test "should create assets_item" do
    assert_difference("AssetsItem.count") do
      post assets_items_url, params: { assets_item: { description: @assets_item.description, media_type: @assets_item.media_type, project_id: @assets_item.project_id, shipped: @assets_item.shipped, title: @assets_item.title } }
    end

    assert_redirected_to assets_item_url(AssetsItem.last)
  end

  test "should show assets_item" do
    get assets_item_url(@assets_item)
    assert_response :success
  end

  test "should get edit" do
    get edit_assets_item_url(@assets_item)
    assert_response :success
  end

  test "should update assets_item" do
    patch assets_item_url(@assets_item), params: { assets_item: { description: @assets_item.description, media_type: @assets_item.media_type, project_id: @assets_item.project_id, shipped: @assets_item.shipped, title: @assets_item.title } }
    assert_redirected_to assets_item_url(@assets_item)
  end

  test "should destroy assets_item" do
    assert_difference("AssetsItem.count", -1) do
      delete assets_item_url(@assets_item)
    end

    assert_redirected_to assets_items_url
  end
end
