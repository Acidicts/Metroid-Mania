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
      post charm_notches_url, params: { charm_notch: { CharmSlot_id: @charm_notch.CharmSlot_id, user_id: @charm_notch.user_id } }
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
    patch charm_notch_url(@charm_notch), params: { charm_notch: { CharmSlot_id: @charm_notch.CharmSlot_id, user_id: @charm_notch.user_id } }
    assert_redirected_to charm_notch_url(@charm_notch)
  end

  test "should destroy charm_notch" do
    assert_difference("CharmNotch.count", -1) do
      delete charm_notch_url(@charm_notch)
    end

    assert_redirected_to charm_notches_url
  end
end
