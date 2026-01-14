require "test_helper"

class Admin::AuditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: 'admin-audit@example.com', password: 'password')
    sign_in_as(@admin, password: 'password')
  end

  test "index shows recent audits" do
    get admin_audits_url
    assert_response :success
    assert_select 'h1', 'Audit Log'
  end
end
