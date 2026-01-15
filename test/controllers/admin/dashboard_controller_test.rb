require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: 'admin4@example.com', password: 'password')
    sign_in_as(@admin, password: 'password')
  end

  test "dashboard shows ship/unship controls for projects" do
    # Create an unshipped project and a shipped project
    p1 = Project.create!(user: users(:one), name: 'Unshipped Project', repository_url: 'x', status: 'unshipped', shipped: false, total_seconds: 3600)
    p2 = Project.create!(user: users(:one), name: 'Shipped Project', repository_url: 'y', status: 'shipped', shipped_at: 1.day.ago, shipped: true, total_seconds: 3600)

    get admin_dashboard_url
    assert_response :success

    # The projects should be visible
    assert_select 'td', text: 'Unshipped Project'
    assert_select 'td', text: 'Shipped Project'

    # There should be at least one Ship button (unshipped project)
    assert_select "form[action$='/ship'] button", text: 'Ship'

    # There should be at least one Force Ship button
    assert_select "form[action$='/force_ship'] button", text: 'Force Ship'

    # There should be at least one Unship button (shipped project)
    assert_select "form[action$='/unship'] button", text: 'Unship'
  end
end
