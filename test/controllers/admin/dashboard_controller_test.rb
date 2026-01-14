require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: 'admin4@example.com', password: 'password')
    sign_in_as(@admin, password: 'password')
  end

  test "dashboard shows ship/unship controls for approved projects" do
    # Create an approved unshipped project and an approved shipped project
    p1 = Project.create!(user: users(:one), name: 'Approved Unshipped', repository_url: 'x', status: 'approved', approved_at: 1.day.ago, shipped: false, total_seconds: 3600)
    p2 = Project.create!(user: users(:one), name: 'Approved Shipped', repository_url: 'y', status: 'approved', approved_at: 1.day.ago, shipped: true, total_seconds: 3600)

    get admin_dashboard_url
    assert_response :success

    # The approved projects should be visible
    assert_select 'td', text: 'Approved Unshipped'
    assert_select 'td', text: 'Approved Shipped'

    # There should be a Ship button for p1 (form action ending with /ship)
    assert_select "form[action$='/ship'] button", text: 'Ship', count: 1

    # There should be a Force Ship button for p1 (form action ending with /force_ship)
    assert_select "form[action$='/force_ship'] button", text: 'Force Ship', count: 1

    # There should be an Unship button for p2 (form action ending with /unship)
    assert_select "form[action$='/unship'] button", text: 'Unship', count: 1
  end
end
