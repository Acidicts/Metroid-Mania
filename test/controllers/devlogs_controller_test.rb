require "test_helper"

class DevlogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @devlog = devlogs(:one)
  end

  test "should get index" do
    get project_devlogs_url(@devlog.project)
    assert_response :success
  end

  test "should get new" do
    get new_project_devlog_url(@devlog.project)
    assert_response :success
  end

  test "should create devlog" do
    assert_difference("Devlog.count") do
      post project_devlogs_url(@devlog.project), params: { devlog: { content: @devlog.content, title: @devlog.title } }
    end

    assert_redirected_to project_url(@devlog.project)
  end

  test "should not create devlog when less than 15 minutes remaining" do
    project = projects(:one)

    # Give this project a limited total_seconds and make existing devlogs fill most of it
    project.update!(total_seconds: 60 * 60)
    project.devlogs.create!(title: 'filler', content: 'fill', log_date: Date.current, duration_minutes: 55)

    assert_no_difference("Devlog.count") do
      post project_devlogs_url(project), params: { devlog: { title: 'Too short', content: 'Not enough time' } }
    end

    assert_response :unprocessable_entity
    assert_select 'div', /Not enough undocumented time left/
  end

  test "admin can sign in with email/password" do
    admin = users(:one)
    admin.update!(email: 'admin@example.com', password: 'password', role: :admin, uid: "admin-#{SecureRandom.uuid}")

    post admin_login_url, params: { email: 'admin@example.com', password: 'password' }
    assert_redirected_to admin_dashboard_url
    assert_equal session[:user_id], admin.id
  end

  test "should show devlog" do
    get project_devlog_url(@devlog.project, @devlog)
    assert_response :success
  end

  test "should get edit" do
    get edit_project_devlog_url(@devlog.project, @devlog)
    assert_response :success
  end

  test "should update devlog" do
    patch project_devlog_url(@devlog.project, @devlog), params: { devlog: { content: @devlog.content, title: @devlog.title } }
    assert_redirected_to project_url(@devlog.project)
  end

  test "should destroy devlog" do
    assert_difference("Devlog.count", -1) do
      delete project_devlog_url(@devlog.project, @devlog)
    end

    assert_redirected_to project_url(@devlog.project)
  end
end
