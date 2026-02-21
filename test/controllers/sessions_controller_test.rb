require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  # simulate simple OmniAuth responses used in tests
  def auth_hash_for(user_email, uid: SecureRandom.hex(6))
    OmniAuth::AuthHash.new(
      provider: "hackclub",
      uid: uid,
      info: { email: user_email }
    )
  end

  test "blocks non-admin login when toggle active" do
    SiteSetting.set("disable_non_admin_logins", "true")

    auth = auth_hash_for("nobody@example.org")
    post auth_hackclub_callback_path, env: { "omniauth.auth" => auth }

    assert_redirected_to root_url
    follow_redirect!
    assert_match(/logins.*disabled/i, response.body)
    assert_nil session[:user_id]
  ensure
    SiteSetting.set("disable_non_admin_logins", "false")
  end

  test "allows admin login even when toggle active" do
    SiteSetting.set("disable_non_admin_logins", "true")
    admin = users(:admin)
    # make sure the auth hash will map to our admin instance
    auth = auth_hash_for(admin.email, uid: admin.uid || SecureRandom.hex(6))
    admin.update!(provider: auth.provider, uid: auth.uid)

    post auth_hackclub_callback_path, env: { "omniauth.auth" => auth }

    assert_redirected_to root_url
    follow_redirect!
    assert_equal admin.id, session[:user_id]
  ensure
    SiteSetting.set("disable_non_admin_logins", "false")
  end
end
