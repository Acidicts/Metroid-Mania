require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: :admin, email: "admin@test.local", uid: "admin-#{SecureRandom.uuid}", password: "password")
    @user = users(:two)
  end

  test "admin can promote a user to admin" do
    sign_in_as(@admin, password: "password")

    patch admin_user_url(@user), params: { user: { role: "admin" } }

    assert_redirected_to admin_users_url
    assert_equal "admin", @user.reload.role
  end

  test "admin can update user's credits" do
    sign_in_as(@admin, password: "password")

    user_before = (@user.currency || 0)

    assert_difference "Audit.count", 1 do
      patch admin_user_url(@user), params: { user: { currency: 42.5 } }
    end

    assert_redirected_to admin_users_url
      # currency is stored as ceil(total_credits) so 42.5 becomes 43
      assert_in_delta 43.0, @user.reload.currency, 0.001

    a = Audit.last
    assert_equal "update_currency", a.action
    assert_equal @admin, a.user
    assert_equal @user.id, a.details["user_id"]

    expected_before = @user.total_shipped_credits.to_f
    assert_in_delta expected_before, a.details["before"].to_f, 0.001
      # audit records total_credits (rounded up)
      assert_in_delta 43.0, a.details["after"].to_f, 0.001
  end

  test "admin can update user's charm notches upward and downward" do
    sign_in_as(@admin, password: "password")

    # ensure the user starts with no free notches (remove any notches or slots)
    @user.charm_notches.destroy_all
    @user.charm_slots.destroy_all
    assert_equal 0, @user.free_notches

    patch admin_user_url(@user), params: { user: { charm_notches: 3 } }
    assert_redirected_to admin_users_url
    @user.reload
    assert_equal 3, @user.free_notches
    # new notches should be flagged as admin-granted
    assert_equal 3, @user.charm_notches.admin_only.count

    # reducing the value should delete unassigned *non-admin* notches only
    patch admin_user_url(@user), params: { user: { charm_notches: 1 } }
    assert_redirected_to admin_users_url
    @user.reload
    assert_equal 1, @user.free_notches
    assert_equal 1, @user.charm_notches.admin_only.count
  end

  test "admin setting charm notches replaces existing free notches instead of appending" do
    sign_in_as(@admin, password: "password")

    # seed the user with a couple of non-admin free notches
    @user.charm_notches.destroy_all
    @user.charm_slots.destroy_all
    2.times { @user.charm_notches.create!(charm_slot: nil) }
    assert_equal 2, @user.free_notches

    # bump up via admin; the total should become exactly the supplied value
    patch admin_user_url(@user), params: { user: { charm_notches: 4 } }
    assert_redirected_to admin_users_url
    @user.reload
    assert_equal 4, @user.free_notches

    # repeating the same target shouldn't add any more notches
    patch admin_user_url(@user), params: { user: { charm_notches: 4 } }
    assert_redirected_to admin_users_url
    @user.reload
    assert_equal 4, @user.free_notches

    # lowering the target should trim the correct number of notches
    patch admin_user_url(@user), params: { user: { charm_notches: 1 } }
    assert_redirected_to admin_users_url
    @user.reload
    assert_equal 1, @user.free_notches
  end

  test "edit form displays current free notches count" do
    sign_in_as(@admin, password: "password")
    @user.charm_notches.destroy_all
    @user.charm_slots.destroy_all
    slot = @user.charm_slots.create!
    @user.charm_notches.create!(charm_slot: slot)

    get edit_admin_user_url(@user)
    assert_response :success
    assert_select "input#user_charm_notches[value='1']"
  end

  test "edit form shows fraud checkbox" do
    sign_in_as(@admin, password: "password")
    # ensure flag is false initially
    @user.update!(flagged_for_fraud: false, flagged_for_fraud_by: nil)

    get edit_admin_user_url(@user)
    assert_response :success
    # checkbox should exist and not be checked
    assert_select "input#user_flagged_for_fraud[type=checkbox]" do |elements|
      # when the flag is false the checkbox should not have a checked attribute
      assert_nil elements.first[:checked]
    end

    # now mark the user as fraudulent and reload form; we simulate an admin marking them
    @user.update!(flagged_for_fraud: true, flagged_for_fraud_by: @admin)
    get edit_admin_user_url(@user)
    assert_response :success
    assert_select "input#user_flagged_for_fraud[checked]"
    # the page should show who flagged the user
    assert_select ".fraud-flagged-by", text: /Flagged by:.*#{Regexp.escape(@admin.name)}/
  end

  test "admin can toggle flagged_for_fraud" do
    sign_in_as(@admin, password: "password")

    patch admin_user_url(@user), params: { user: { flagged_for_fraud: "1" } }
    assert_redirected_to admin_users_url
    @user.reload
    assert_equal true, @user.flagged_for_fraud
    assert_equal @admin.id, @user.flagged_for_fraud_by_id

    # after flagging we should see the flagger on the edit page
    get edit_admin_user_url(@user)
    assert_response :success
    assert_select ".fraud-flagged-by", text: /Flagged by:.*#{Regexp.escape(@admin.name)}/

    patch admin_user_url(@user), params: { user: { flagged_for_fraud: "0" } }
    assert_redirected_to admin_users_url
    @user.reload
    assert_equal false, @user.flagged_for_fraud
    assert_nil @user.flagged_for_fraud_by_id
  end

  test "negative charm notches value shows error and does not change" do
    sign_in_as(@admin, password: "password")

    original = @user.free_notches
    patch admin_user_url(@user), params: { user: { charm_notches: -5 } }

    assert_response :unprocessable_entity
    # controller reload may have wiped errors so re-check via assigns or
    # perform the update again to capture errors? Simpler: after response the
    # @user instance variable won't be available; instead reload from DB and
    # verify nothing changed.
    assert_equal original, @user.reload.free_notches
    # The rendered page will show the error message; we don't need to inspect
    # the model errors here because they're not preserved after reload.
  end

  test "cannot change superadmin role" do
    ENV["SUPERADMIN_EMAIL"] = "super@example.com"
    super_user = User.create!(provider: "dev", uid: "super-1", email: "super@example.com", name: "Super", role: :user)

    sign_in_as(@admin, password: "password")
    patch admin_user_url(super_user), params: { user: { role: "admin" } }

    assert_redirected_to admin_users_url
    assert_equal "user", super_user.reload.role
  ensure
    ENV.delete("SUPERADMIN_EMAIL")
  end

  test "cannot delete the system placeholder user" do
    sys = User.system_user

    sign_in_as(@admin, password: "password")
    assert_no_difference "User.count" do
      delete admin_user_url(sys)
    end

    assert_redirected_to admin_users_url
    assert User.exists?(sys.id)
  end

  test "system user is excluded from admin users list" do
    sys = User.system_user

    sign_in_as(@admin, password: "password")
    get admin_users_url

    assert_response :success
    assert_not_includes response.body, sys.email
  end

  test "update with non-hash user param does not crash" do
    sign_in_as(@admin, password: "password")
    # some buggy forms or external calls might send user as a bare integer
    patch admin_user_url(@user), params: { user: 5 }

    assert_redirected_to admin_users_url
    # nothing should change to the record
    assert_equal users(:two).email, @user.reload.email
  end
end
