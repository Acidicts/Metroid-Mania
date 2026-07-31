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
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth

    # Prevent the user from being auto-promoted to superadmin
    # (slack_id nil == ENV["SUPERADMIN_SLACK"] nil would be true)
    ENV["SUPERADMIN_SLACK"] = "U_NEVER_MATCH"

    get "/auth/hackclub/callback"
    assert_redirected_to root_url
    follow_redirect!
    assert_match(/logins.*disabled/i, response.body)
    assert_nil session[:user_id]
  ensure
    SiteSetting.set("disable_non_admin_logins", "false")
    Rails.cache.clear
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:hackclub)
    ENV.delete("SUPERADMIN_SLACK")
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

  test "new user with matching SUPERADMIN_SLACK gets superadmin role when none exists" do
    ENV["SUPERADMIN_SLACK"] = "U_SUPER_ADMIN"
    assert_not User.exists?(role: :superadmin), "no superadmin should exist yet"

    auth = auth_hash_for("superadmin@example.com", uid: "uid-superadmin")
    auth.info.slack_id = "U_SUPER_ADMIN"

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth

    get "/auth/hackclub/callback"

    new_user = User.find_by(uid: "uid-superadmin")
    assert new_user.present?, "user should have been created"
    assert_equal "superadmin", new_user.role
    assert new_user.superadmin?
  ensure
    ENV.delete("SUPERADMIN_SLACK")
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:hackclub)
  end

  test "new user with non-matching SUPERADMIN_SLACK stays as regular user" do
    ENV["SUPERADMIN_SLACK"] = "U_OTHER_ADMIN"

    auth = auth_hash_for("regular@example.com", uid: "uid-regular")
    auth.info.slack_id = "U_DIFFERENT_ID"

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth

    get "/auth/hackclub/callback"

    new_user = User.find_by(uid: "uid-regular")
    assert new_user.present?, "user should have been created"
    assert_equal "user", new_user.role
    assert_not new_user.superadmin?
  ensure
    ENV.delete("SUPERADMIN_SLACK")
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:hackclub)
  end

  test "new user with matching SUPERADMIN_SLACK does not get superadmin if one already exists" do
    ENV["SUPERADMIN_SLACK"] = "U_NEW_SUPER"
    existing = User.create!(provider: "dev", uid: "existing-super", email: "existing@example.com",
                            name: "Existing Super", role: :superadmin)
    assert User.exists?(role: :superadmin)

    auth = auth_hash_for("another_super@example.com", uid: "uid-another-super")
    auth.info.slack_id = "U_NEW_SUPER"

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth

    get "/auth/hackclub/callback"

    new_user = User.find_by(uid: "uid-another-super")
    assert new_user.present?, "user should have been created"
    assert_equal "user", new_user.role, "should not be promoted when superadmin already exists"
  ensure
    ENV.delete("SUPERADMIN_SLACK")
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:hackclub)
  end

  test "existing user with matching SUPERADMIN_SLACK is not promoted on subsequent login" do
    ENV["SUPERADMIN_SLACK"] = "U_EXISTING"
    existing = User.create!(provider: "hackclub", uid: "uid-existing", email: "existing_user@example.com",
                            name: "Existing User", role: :user, slack_id: "U_EXISTING")
    assert_equal "user", existing.role

    auth = auth_hash_for(existing.email, uid: existing.uid)
    auth.info.slack_id = "U_EXISTING"

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:hackclub] = auth

    get "/auth/hackclub/callback"

    existing.reload
    assert_equal "user", existing.role, "existing user should not be promoted on login"
  ensure
    ENV.delete("SUPERADMIN_SLACK")
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
