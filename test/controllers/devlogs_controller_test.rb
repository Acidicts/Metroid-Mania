require "test_helper"

class DevlogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @project.update!(total_seconds: 86400)
    sign_in_as(@project.user)
  end

  test "should get index" do
    get project_devlogs_url(@project)
    assert_response :success
  end

  test "should get new" do
    get new_project_devlog_url(@project)
    assert_response :success
  end

  test "should create devlog" do
    assert_difference("Devlog.count") do
      post project_devlogs_url(@project), params: { devlog: { title: "New Work", content: "Did stuff", duration_minutes: 20 } }
    end
    assert_redirected_to project_path(@project)
  end

  test "create blocks on insufficient time" do
    @project.devlogs.destroy_all
    @project.update_column(:total_seconds, 60)
    post project_devlogs_url(@project), params: { devlog: { title: "Fail", content: "x", duration_minutes: 20 } }
    assert_response :unprocessable_entity
  end

  test "admin can create devlog on any project" do
    admin = users(:admin)
    sign_in_as(admin)
    assert_difference("Devlog.count") do
      post project_devlogs_url(@project), params: { devlog: { title: "Admin Work", content: "Admin stuff", duration_minutes: 20 } }
    end
    assert_redirected_to project_path(@project)
  end

  test "should get show" do
    devlog = @project.devlogs.first
    get project_devlog_url(@project, devlog)
    assert_response :success
  end

  test "should get edit" do
    devlog = @project.devlogs.where(user: @project.user).first
    get edit_project_devlog_url(@project, devlog)
    assert_response :success
  end

  test "should update devlog" do
    devlog = @project.devlogs.where(user: @project.user).first
    patch project_devlog_url(@project, devlog), params: { devlog: { title: "Updated Title" } }
    assert_redirected_to project_path(@project)
  end

  test "non-owner cannot edit devlog" do
    devlog = @project.devlogs.where(user: @project.user).first
    sign_in_as(users(:two))
    patch project_devlog_url(@project, devlog), params: { devlog: { title: "Hacked" } }
    assert_redirected_to project_path(@project)
  end

  test "should destroy devlog" do
    devlog = @project.devlogs.where(user: @project.user).first
    assert_difference("Devlog.count", -1) do
      delete project_devlog_url(@project, devlog)
    end
    assert_redirected_to project_path(@project)
  end
end
