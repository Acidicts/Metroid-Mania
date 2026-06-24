require "test_helper"

class Admin::ProjectTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project_tag = project_tags(:one)
    admin = users(:one)
    admin.update!(role: :admin, email: "admin-tags@example.com", password: "password")
    sign_in_as(admin, password: "password")
  end

  test "should get index" do
    get admin_project_tags_url
    assert_response :success
  end

  test "should get show" do
    get admin_project_tag_url(@project_tag)
    assert_response :success
  end

  test "should get new" do
    get new_admin_project_tag_url
    assert_response :success
  end

  test "should get edit" do
    get edit_admin_project_tag_url(@project_tag)
    assert_response :success
  end

  test "should create project_tag" do
    assert_difference("ProjectTag.count") do
      # submitting via the nicer `tag` alias should work
      post admin_project_tags_url, params: { project_tag: { tag: "newtag", project_id: projects(:one).id } }
    end
    assert_redirected_to admin_project_tags_path
  end

  test "can create a global project_tag without a project" do
    assert_difference("ProjectTag.count") do
      post admin_project_tags_url, params: { project_tag: { tag: "unique_global_tag" } }
    end
    assert_redirected_to admin_project_tags_path
    assert_nil ProjectTag.last.project_id
  end

  test "should update project_tag" do
    patch admin_project_tag_url(@project_tag), params: { project_tag: { tag: "updated" } }
    assert_redirected_to admin_project_tags_path
    assert_equal "updated", @project_tag.reload.tag
  end

  test "should destroy project_tag" do
    assert_difference("ProjectTag.count", -1) do
      delete admin_project_tag_url(@project_tag)
    end
    assert_redirected_to admin_project_tags_path
  end
end
