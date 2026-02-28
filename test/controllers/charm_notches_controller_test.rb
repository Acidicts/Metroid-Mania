require "test_helper"

class CharmNotchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @charm_notch = charm_notches(:one)
  end

  test "should get index" do
    get charm_notches_url
    assert_response :success
  end

  test "should get new" do
    get new_charm_notch_url
    assert_response :success
  end

  test "should create charm_notch" do
    assert_difference("CharmNotch.count") do
      post charm_notches_url, params: { charm_notch: { charm_slot_id: @charm_notch.charm_slot_id, user_id: @charm_notch.user_id } }
    end

    assert_redirected_to charm_notch_url(CharmNotch.last)
  end

  test "should show charm_notch" do
    get charm_notch_url(@charm_notch)
    assert_response :success
  end

  test "should get edit" do
    get edit_charm_notch_url(@charm_notch)
    assert_response :success
  end

  test "should update charm_notch" do
    patch charm_notch_url(@charm_notch), params: { charm_notch: { charm_slot_id: @charm_notch.charm_slot_id, user_id: @charm_notch.user_id } }
    assert_redirected_to charm_notch_url(@charm_notch)
  end

  test "should destroy charm_notch" do
    assert_difference("CharmNotch.count", -1) do
      delete charm_notch_url(@charm_notch)
    end

    assert_redirected_to charm_notches_url
  end

  # donation-specific tests --------------------------------------------------
  test "should donate charm notch when available" do
    donor = users(:one)
    recipient = users(:two)
    sign_in_as donor

    # donor has at least one free notch
    available = CharmNotch.create!(user: donor, charm_slot: nil)

    assert_difference("Audit.count", 1) do
      post donate_charm_notches_path(recipient)
    end

    assert_redirected_to user_profile_path(recipient)
    assert_equal recipient, available.reload.user
    assert_match(/donated successfully/, flash[:notice].to_s)
  end

  test "should warn when no available notches to donate" do
    donor = users(:one)
    recipient = users(:two)
    sign_in_as donor

    post donate_charm_notches_path(recipient)
    assert_redirected_to user_profile_path(recipient)
    assert_match(/no available charm notches/i, flash[:warning].to_s)
  end

  test "donate action requires login" do
    # no signed in user at all
    post donate_charm_notches_path(users(:two))
    assert_redirected_to root_path
    assert_match(/must be logged in/i, flash[:warning].to_s)
  end
end
