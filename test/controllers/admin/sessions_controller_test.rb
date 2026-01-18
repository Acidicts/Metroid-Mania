require 'test_helper'

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "AUTO_ADMIN unset -> auto admin enabled in test env" do
    old = ENV.delete('AUTO_ADMIN')
    get admin_login_path
    assert_redirected_to admin_root_path
    assert_match /Auto-signed in/, flash[:notice]
  ensure
    ENV['AUTO_ADMIN'] = old
  end

  test "AUTO_ADMIN = '1' enables auto admin" do
    old = ENV['AUTO_ADMIN']
    ENV['AUTO_ADMIN'] = '1'
    get admin_login_path
    assert_redirected_to admin_root_path
    assert_match /Auto-signed in/, flash[:notice]
  ensure
    ENV['AUTO_ADMIN'] = old
  end

  test "AUTO_ADMIN = '0' disables auto admin even in test env" do
    old = ENV['AUTO_ADMIN']
    ENV['AUTO_ADMIN'] = '0'
    get admin_login_path
    assert_response :success
    assert_match /password/i, response.body
    assert_nil flash[:notice]
  ensure
    ENV['AUTO_ADMIN'] = old
  end
end
