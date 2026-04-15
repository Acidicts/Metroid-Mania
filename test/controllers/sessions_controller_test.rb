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
    # OmniAuth handles its own CSRF/state checks in middleware; enable
    # test mode and inject our mock response rather than posting directly.
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth

    get "/auth/hackclub/callback"
    assert_redirected_to root_url
    follow_redirect!
    assert_match(/logins.*disabled/i, response.body)
    assert_nil session[:user_id]
  ensure
    SiteSetting.set("disable_non_admin_logins", "false")
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:hackclub)
  end

  test "allows admin login even when toggle active" do
    SiteSetting.set("disable_non_admin_logins", "true")
    admin = users(:admin)
    auth = auth_hash_for(admin.email, uid: admin.uid || SecureRandom.hex(6))
    admin.update!(provider: auth.provider, uid: auth.uid)

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth

    get "/auth/hackclub/callback"

    assert_redirected_to root_url
    follow_redirect!
    assert_equal admin.id, session[:user_id]
  ensure
    SiteSetting.set("disable_non_admin_logins", "false")
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:hackclub)
  end

  test "redirects to local origin after login" do
    user = users(:one)
    auth = auth_hash_for(user.email, uid: user.uid || SecureRandom.hex(6))
    user.update!(provider: auth.provider, uid: auth.uid)

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth

    get "/auth/hackclub/callback", params: { origin: "/projects/1" }

    assert_redirected_to "/projects/1"
    follow_redirect!
    assert_equal user.id, session[:user_id]
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:hackclub)
  end

  test "rejects unsafe origin and redirects to root" do
    user = users(:one)
    auth = auth_hash_for(user.email, uid: user.uid || SecureRandom.hex(6))
    user.update!(provider: auth.provider, uid: auth.uid)

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth

    get "/auth/hackclub/callback", params: { origin: "https://evil.com" }

    assert_redirected_to root_url
    follow_redirect!
    assert_equal user.id, session[:user_id]
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:hackclub)
  end

  test "callback clears stale return_to even when origin is present" do
    user = users(:one)
    auth = auth_hash_for(user.email, uid: user.uid || SecureRandom.hex(6))
    user.update!(provider: auth.provider, uid: auth.uid)

    # Set session[:return_to] through RSVP guest flow.
    get rsvp_submit_after_login_url
    assert_equal "/rsvp/submit_after_login", session[:return_to]

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth

    get "/auth/hackclub/callback", params: { origin: "/projects" }

    assert_redirected_to "/projects"
    assert_nil session[:return_to]
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:hackclub)
  end
end
