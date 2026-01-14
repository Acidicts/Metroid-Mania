require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: 'admin@test.local', uid: "admin-#{SecureRandom.uuid}", password: 'password')
    @user = users(:two)
  end

  test "admin can promote a user to admin" do
    sign_in_as(@admin, password: 'password')

    patch admin_user_url(@user), params: { user: { role: 'admin' } }

    assert_redirected_to admin_users_url
    assert_equal 'admin', @user.reload.role
  end

  test "cannot change superadmin role" do
    ENV['SUPERADMIN_EMAIL'] = 'super@example.com'
    super_user = User.create!(provider: 'dev', uid: 'super-1', email: 'super@example.com', name: 'Super', role: :user)

    sign_in_as(@admin, password: 'password')
    patch admin_user_url(super_user), params: { user: { role: 'admin' } }

    assert_redirected_to admin_users_url
    assert_equal 'user', super_user.reload.role
  ensure
    ENV.delete('SUPERADMIN_EMAIL')
  end
end
