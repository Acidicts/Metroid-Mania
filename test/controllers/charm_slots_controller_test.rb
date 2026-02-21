require "test_helper"

class CharmSlotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @charm_slot = charm_slots(:one)
    # ensure asset check passes during view rendering in tests
    ApplicationController.helpers.singleton_class.class_eval do
      define_method(:asset_exists?) { |*| true }
    end
  end

  test "should get index" do
    get charm_slots_url
    assert_response :success
  end

  test "non-admin index redirects to loadout" do
    user = users(:one)
    sign_in_as(user)
    get charm_slots_url
    assert_redirected_to loadout_charm_slots_url
  end

  test "loadout shows current user's slots and creates missing records" do
    user = users(:one)
    user.update!(charm_slots: 2)
    sign_in_as(user)

    # no slots exist yet
    assert_equal 0, user.charm_slots.count

    get loadout_charm_slots_url
    assert_response :success

    # callback should have created the missing slots
    assert_equal 2, user.reload.charm_slots.count

    # rendered page should contain two slot wrappers (each div has an id starting with "charm_slot_")
    assert_select "#charm_slots" do
      assert_select "div[id^=charm_slot_]", 2
    end
  end

  test "should get new" do
    get new_charm_slot_url
    assert_response :success
  end

  test "should create charm_slot" do
    assert_difference("CharmSlot.count") do
      post charm_slots_url, params: { charm_slot: { order_id: @charm_slot.order_id, user_id: @charm_slot.user_id } }
    end

    assert_redirected_to charm_slot_url(CharmSlot.last)
  end

  test "can create charm_slot without an order" do
    assert_difference("CharmSlot.count") do
      post charm_slots_url, params: { charm_slot: { user_id: @charm_slot.user_id } }
    end

    created = CharmSlot.last
    assert_nil created.order
    assert_redirected_to charm_slot_url(created)
  end

  test "should show charm_slot" do
    get charm_slot_url(@charm_slot)
    assert_response :success
  end

  test "should get edit" do
    get edit_charm_slot_url(@charm_slot)
    assert_response :success
  end

  test "should update charm_slot" do
    patch charm_slot_url(@charm_slot), params: { charm_slot: { order_id: @charm_slot.order_id, user_id: @charm_slot.user_id } }
    assert_redirected_to charm_slot_url(@charm_slot)
  end

  test "should destroy charm_slot" do
    assert_difference("CharmSlot.count", -1) do
      delete charm_slot_url(@charm_slot)
    end

    assert_redirected_to charm_slots_url
  end
end
