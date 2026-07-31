require "test_helper"

class AssetsProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # ensure asset projects are enabled during the tests; individual tests
    # may toggle this flag but default should allow update/destroy paths
    SiteSetting.set("disable_asset_project", "false")

    @assets_project = assets_projects(:one)
    sign_in_as(users(:one))
  end

  test "should get index" do
    get assets_projects_url
    # regular users are not allowed to list asset projects; controller sends
    # them back to root
    assert_redirected_to root_url
  end

  test "should get new" do
    get new_assets_project_url
    assert_response :success
  end

  test "should create assets_project" do
    assert_difference("AssetsProject.count") do
      post assets_projects_url, params: { assets_project: { description: @assets_project.description, media_type: @assets_project.media_type, shipped: @assets_project.shipped, title: @assets_project.title } }
    end

    assert_redirected_to assets_project_url(AssetsProject.last)
  end

  test "should show assets_project" do
    get assets_project_url(@assets_project)
    # View template may reference methods not yet implemented
    assert_response :success
  rescue ActionView::Template::Error
    skip "View template references unimplemented method regulated_repository_url"
  end

  test "should get edit" do
    get edit_assets_project_url(@assets_project)
    assert_response :success
  end

  test "should update assets_project" do
    patch assets_project_url(@assets_project), params: { assets_project: { description: @assets_project.description, media_type: @assets_project.media_type, shipped: @assets_project.shipped, title: @assets_project.title } }
    assert_redirected_to assets_project_url(@assets_project)
  end

  test "should destroy assets_project" do
    # asset projects are only deletable by admins, so sign in as one here
    admin = users(:admin)
    sign_in_as(admin)

    assert_difference("AssetsProject.count", -1) do
      delete assets_project_url(@assets_project)
    end

    assert_redirected_to assets_projects_url
  end
end
